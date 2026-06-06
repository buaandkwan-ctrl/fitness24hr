public with sharing class JettsBranchLookupController {

    public class BranchRequest {
        @InvocableVariable(label='Search term (area, BTS station, keyword)' required=false)
        public String searchTerm;

        @InvocableVariable(label='Branch type filter (Jetts Black / Flagship HYROX / blank = all)')
        public String branchTypeFilter;

        @InvocableVariable(label='Max results to return (default 5)')
        public Integer maxResults;
    }

    public class BranchResult {
        @InvocableVariable(label='Formatted branch list for agent to display')
        public String branchListText;

        @InvocableVariable(label='Number of branches found')
        public Integer matchCount;
    }

    @InvocableMethod(
        label='Find Jetts Branches by Keyword'
        description='Searches Branch__c records. If search term matches a BTS/MRT station, finds nearest branches by GPS distance. Otherwise falls back to keyword search.'
        callout=false
    )
    public static List<BranchResult> findBranches(List<BranchRequest> requests) {
        List<BranchResult> results = new List<BranchResult>();
        for (BranchRequest req : requests) {
            results.add(doSearch(req));
        }
        return results;
    }

    private static BranchResult doSearch(BranchRequest req) {
        Integer maxRows = (req.maxResults != null && req.maxResults > 0) ? req.maxResults : 5;

        // ── Step 1: ลองหาสถานี BTS/MRT จากทุกคำใน searchTerm ──
        if (String.isNotBlank(req.searchTerm)) {
            try {
                List<String> tokens = req.searchTerm.trim().split('\\s+');
                for (String token : tokens) {
                    if (token.length() < 2) continue;
                    String stationTerm = '%' + token + '%';
                    List<BTS_MRT_Station__c> stations = [
                        SELECT Id, Station_Name_EN__c, Station_Name_TH__c, Line__c,
                               Location__Latitude__s, Location__Longitude__s
                        FROM BTS_MRT_Station__c
                        WHERE Station_Name_EN__c LIKE :stationTerm
                           OR Station_Name_TH__c LIKE :stationTerm
                        WITH SYSTEM_MODE
                        LIMIT 1
                    ];
                    if (!stations.isEmpty()) {
                        return searchByDistance(stations[0], req.branchTypeFilter, maxRows);
                    }
                }
            } catch (Exception e) {
                // fall through to keyword search
            }
        }

        // ── Step 2: Fallback — keyword search แบบเดิม ──
        return searchByKeyword(req.searchTerm, req.branchTypeFilter, maxRows);
    }

    private static Double haversineKm(Double lat1, Double lon1, Double lat2, Double lon2) {
        if (lat2 == null || lon2 == null) return null;
        Double R = 6371.0;
        Double dLat = Math.PI / 180.0 * (lat2 - lat1);
        Double dLon = Math.PI / 180.0 * (lon2 - lon1);
        Double a = Math.sin(dLat/2) * Math.sin(dLat/2)
                 + Math.cos(Math.PI/180.0*lat1) * Math.cos(Math.PI/180.0*lat2)
                 * Math.sin(dLon/2) * Math.sin(dLon/2);
        return R * 2.0 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
    }

    private static BranchResult searchByDistance(BTS_MRT_Station__c station, String branchTypeFilter, Integer maxRows) {
        Double lat = station.Location__Latitude__s;
        Double lon = station.Location__Longitude__s;

        List<Branch__c> branches;
        if (String.isNotBlank(branchTypeFilter)) {
            branches = [
                SELECT Name, Branch_Type__c, District__c, Full_Address__c,
                       Location__Latitude__s, Location__Longitude__s
                FROM Branch__c
                WHERE Active__c = true
                  AND Branch_Type__c = :branchTypeFilter
                WITH USER_MODE
                ORDER BY DISTANCE(Location__c, GEOLOCATION(:lat, :lon), 'km')
                LIMIT :maxRows
            ];
        } else {
            branches = [
                SELECT Name, Branch_Type__c, District__c, Full_Address__c,
                       Location__Latitude__s, Location__Longitude__s
                FROM Branch__c
                WHERE Active__c = true
                WITH USER_MODE
                ORDER BY DISTANCE(Location__c, GEOLOCATION(:lat, :lon), 'km')
                LIMIT :maxRows
            ];
        }

        BranchResult result = new BranchResult();
        result.matchCount = branches.size();

        if (branches.isEmpty()) {
            result.branchListText = System.Label.Jetts_Branch_NoMatch_Th + ' ' + System.Label.Jetts_Branch_NoMatch_En;
            return result;
        }

        String stationLabel = station.Station_Name_TH__c + ' (' + station.Line__c + ')';
        String output = 'สาขาใกล้สถานี ' + stationLabel + ':\n\n';

        for (Branch__c b : branches) {
            String typeTag = '';
            if (b.Branch_Type__c == 'Jetts Black') typeTag = ' [Jetts Black]';
            else if (b.Branch_Type__c == 'Flagship HYROX') typeTag = ' [Flagship HYROX]';

            String distLabel = '';
            Double distKm = haversineKm(lat, lon, b.Location__Latitude__s, b.Location__Longitude__s);
            if (distKm != null) {
                Double rounded = Math.round(distKm * 10) / 10.0;
                distLabel = ' (~' + rounded + ' km)';
            }

            output += '* ' + b.Name + typeTag + distLabel + '\n';
            if (String.isNotBlank(b.Full_Address__c)) {
                output += '  ' + b.Full_Address__c + '\n';
            } else if (String.isNotBlank(b.District__c)) {
                output += '  ' + b.District__c + '\n';
            }
        }

        result.branchListText = output.trim();
        return result;
    }

    private static BranchResult searchByKeyword(String searchTerm, String branchTypeFilter, Integer maxRows) {
        String term = String.isBlank(searchTerm) ? '' : '%' + searchTerm.trim() + '%';

        List<Branch__c> branches;

        if (String.isBlank(searchTerm)) {
            if (String.isNotBlank(branchTypeFilter)) {
                branches = [
                    SELECT Name, Branch_Type__c, District__c, Full_Address__c, Area_Keywords__c, Region__c
                    FROM Branch__c
                    WHERE Active__c = true AND Branch_Type__c = :branchTypeFilter
                    WITH USER_MODE
                    ORDER BY Region__c, Name
                    LIMIT :maxRows
                ];
            } else {
                branches = [
                    SELECT Name, Branch_Type__c, District__c, Full_Address__c, Area_Keywords__c, Region__c
                    FROM Branch__c
                    WHERE Active__c = true
                    WITH USER_MODE
                    ORDER BY Region__c, Name
                    LIMIT :maxRows
                ];
            }
        } else if (String.isNotBlank(branchTypeFilter)) {
            branches = [
                SELECT Name, Branch_Type__c, District__c, Full_Address__c, Area_Keywords__c, Region__c
                FROM Branch__c
                WHERE Active__c = true
                  AND Branch_Type__c = :branchTypeFilter
                  AND (
                    Name               LIKE :term
                    OR District__c     LIKE :term
                    OR Area_Keywords__c LIKE :term
                    OR Region__c       LIKE :term
                    OR Full_Address__c  LIKE :term
                  )
                WITH USER_MODE
                ORDER BY Name
                LIMIT :maxRows
            ];
        } else {
            branches = [
                SELECT Name, Branch_Type__c, District__c, Full_Address__c, Area_Keywords__c, Region__c
                FROM Branch__c
                WHERE Active__c = true
                  AND (
                    Name               LIKE :term
                    OR District__c     LIKE :term
                    OR Area_Keywords__c LIKE :term
                    OR Region__c       LIKE :term
                    OR Full_Address__c  LIKE :term
                  )
                WITH USER_MODE
                ORDER BY Name
                LIMIT :maxRows
            ];
        }

        BranchResult result = new BranchResult();
        result.matchCount = branches.size();

        if (branches.isEmpty()) {
            result.branchListText = System.Label.Jetts_Branch_NoMatch_Th + ' ' + System.Label.Jetts_Branch_NoMatch_En;
            return result;
        }

        String output = '';
        for (Branch__c b : branches) {
            String typeTag = '';
            if (b.Branch_Type__c == 'Jetts Black') typeTag = ' [Jetts Black]';
            else if (b.Branch_Type__c == 'Flagship HYROX') typeTag = ' [Flagship HYROX]';

            output += '* ' + b.Name + typeTag + '\n';
            if (String.isNotBlank(b.Full_Address__c)) {
                output += '  ' + b.Full_Address__c + '\n';
            } else if (String.isNotBlank(b.District__c)) {
                output += '  ' + b.District__c + '\n';
            }
        }

        result.branchListText = output.trim();
        return result;
    }
}
