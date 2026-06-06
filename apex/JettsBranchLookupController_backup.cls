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
        description='Searches Branch__c records by name, district, area keywords, and region. Returns a formatted text list for the Agentforce agent to present to the customer.'
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
        String term = String.isBlank(req.searchTerm) ? '' : '%' + req.searchTerm.trim() + '%';
        Integer maxRows = (req.maxResults != null && req.maxResults > 0) ? req.maxResults : 5;

        List<Branch__c> branches;

        if (String.isBlank(req.searchTerm)) {
            // No search term — return all active branches (capped)
            if (String.isNotBlank(req.branchTypeFilter)) {
                branches = [
                    SELECT Name, Branch_Type__c, District__c, Full_Address__c, Area_Keywords__c, Region__c
                    FROM Branch__c
                    WHERE Active__c = true AND Branch_Type__c = :req.branchTypeFilter
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
        } else if (String.isNotBlank(req.branchTypeFilter)) {
            branches = [
                SELECT Name, Branch_Type__c, District__c, Full_Address__c, Area_Keywords__c, Region__c
                FROM Branch__c
                WHERE Active__c = true
                  AND Branch_Type__c = :req.branchTypeFilter
                  AND (
                    Name            LIKE :term
                    OR District__c  LIKE :term
                    OR Area_Keywords__c LIKE :term
                    OR Region__c    LIKE :term
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
                    Name            LIKE :term
                    OR District__c  LIKE :term
                    OR Area_Keywords__c LIKE :term
                    OR Region__c    LIKE :term
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
