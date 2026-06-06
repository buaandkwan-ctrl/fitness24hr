# book_class

## Description
Books a specific fitness class for a customer who has confirmed the class name, branch, and their phone number. Creates a ClassBooking record via the Jetts_AgentBookClass Flow.

## Instructions

IF class_booking_confirmed == True:
- การจองของคุณเสร็จสมบูรณ์แล้วครับ/ค่ะ พบกันในคลาสนะครับ/ค่ะ 🏋
- Your booking is already confirmed 🏋 See you in class 💪
- มีอะไรให้ช่วยเพิ่มเติมไหมครับ/ค่ะ? Is there anything else I can help with?

ELSE:
STEP 1 — ALWAYS call collect_booking_info FIRST to store any class name, branch, and phone number already known from the conversation. Use the current conversation context to fill in as many fields as possible. Set class_to_book, branch_interest, and customer_phone to whatever values are already known; leave unknown ones as empty string.

STEP 2 — After storing, check which of the three items are still empty:
1. class_to_book (which class, e.g. Body Pump, RPM, Yoga Flow)
2. branch_interest (which branch, e.g. Asok, Siam Square One, The PARQ)
3. customer_phone (phone number for membership lookup)

Ask for any missing items politely in the customer's language.

STEP 3 — Once all three are known (call collect_booking_info again if needed to store newly provided values), call book_class_action.
Do NOT call book_class_action more than once per session.

After book_class_action returns:
- If outputMessage contains "จองคลาสสำเร็จ" or "Booking confirmed", display it and stop.
- Otherwise display outputMessage as the error and let the customer retry.

## Actions
- collect_booking_info: Collect class name, branch, and phone number for booking
  - class_to_book → Agent Populated
  - branch_interest → Agent Populated
  - customer_phone → Agent Populated

- book_class_flow: Book the fitness class by calling the Jetts_AgentBookClass Flow. Only call when class name, branch, and phone number are all known.
  - Available when: customer_phone != "" AND class_to_book != "" AND branch_interest != ""
  - inputPhone = customer_phone
  - inputSessionId = ""
  - inputBranchName = branch_interest
  - inputClassName = class_to_book
  - inputDateHint = "today"
  - outputBookingId (output)
  - outputMessage (output)
  - Sets class_booking_confirmed = True

- go_to_router
