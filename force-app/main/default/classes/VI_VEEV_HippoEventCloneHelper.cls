/**
 * @description       : Application logic for creating edical Events and Atendies out from  Hippo events and Attendees.
 * @author            : zoltan.nagy@veeva.com
 * @group             :
 * @last modified on  : 12-02-2025
 * @last modified by  : daniel.magyar@veeva.com
 **/
public without sharing class VI_VEEV_HippoEventCloneHelper {
    private static final String HIPPO_ATTENDEE_RT_NAME = 'Hippo_Event_Attendee';
    private static final String HIPPO_EVENT_DRAFT_STATUS = 'Draft'; //not in use
    private static final String HIPPO_EVENT_APPROVED_STATUS = 'Approved';
    private static final String HIPPO_EVENT_COMPLETED_STATUS = 'Completed';
    private static final String HIPPO_EVENT_TERMINATED_STATUS = 'Terminated';
    private static final String FRANCE_ONLY = 'France';
    private static final String UK_ONLY = 'United Kingdom';
    private static final Set<String> INTERACTION_UPDATE_STATUSES = new Set<String>{ 'Cancelled', 'Terminated', 'Rejected' };

    private static final Map<String, String> HIPPO_EVENT_RT_NAME_MAP = new Map<String, String>{ 'Spain' => 'ES_Hippo_Event', 'France' => 'FR_Hippo_Event', 'United Kingdom' => 'UK_Hippo_Event' };

    private static final Map<String, String> HIPPO_COMPLETED_EVENT_RT_NAME_MAP = new Map<String, String>{ 'Spain' => 'ES_Completed_Hippo_Event', 'France' => 'FR_Completed_Hippo_Event', 'United Kingdom' => 'VIA_UK_Completed_Medical_Event' };

    private static final Map<String, String> COUNTRY_MAP = new Map<String, String>{ 'Spain' => 'ES', 'France' => 'FR', 'United Kingdom' => 'UK' };

    private static final Set<String> VALID_VIA_HIP_SUBTYPES = new Set<String>{ 'Commercial' };

    private static final Map<String, String> FIELD_MAPPING = new Map<String, String>{
        'Id' => 'VIA_Hippo_Event__c',
        'Name' => 'Name',
        'Start_Event_Date__c' => 'Start_Date_vod__c',
        'End_Event_Date__c' => 'End_Date_vod__c',
        'TrackingNumber__c' => 'VIA_Tracking_Number__c',
        'Status__c' => 'VIA_Status__c',
        'Event_Type__c' => 'VIA_Event_Type__c',
        'Type__c' => 'VIA_Type__c',
        'Requesting_Party_Name__c' => 'VIA_Requesting_Party_Name__c',
        'Requesting_Party_Title__c' => 'VIA_Requesting_Party_Title__c',
        'Requesting_Party_Department__c' => 'VIA_Requesting_Party_Department__c',
        'Requesting_Party_Location__c' => 'VIA_Requesting_Party_Location__c',
        'OwnerId' => 'OwnerId'
    };

    private static final Map<String, String> FIELD_MAPPING_FR = new Map<String, String>{
        'Sum_of_Financial_Amounts__c' => 'MYL_Planned_Cost_Total__c',
        'Business_Unit__c' => '',
        'Event_subtype__c' => '',
        'Event_Location__c' => 'EPD_FR_MED_City__c',
        'zipcode__c' => 'EPD_FR_MED_Postal_Code__c',
        'Address__c' => 'EPD_FR_MED_Address_Line_1__c',
        'VIA_HIP_Sum_of_Facilities_Amounts__c' => 'VIA_Amount_room_rental_HT__c',
        'Event_venue__c' => 'Location__c'
    };

    private static final Map<String, String> FIELD_MAPPING_UK = new Map<String, String>{ 'Type__c' => 'Event_Type__c', 'Description__c' => 'Description_vod__c', 'Organizer__c' => 'EPD_FR_MED_Organization_Name__c', 'Third_party_organizer_Organizer_Name__c' => 'VIA_Requesting_Party_Name__c' };

    private static final Map<String, String> EVENT_AMOUNT_TO_EXPENSE_FIELD_MAPPING = new Map<String, String>{ 'Cost__c' => 'EPD_Planned_Cost__c', 'Currency__c' => 'CurrencyIsoCode', 'Label__c' => 'EPD_Type__c' };

    private static final Map<String, String> LABEL_TO_EPD_TYPE_MAPPING = new Map<String, String>{ 'Travel Cost' => 'Travel cost', 'Accommodation' => 'Stay Expenses', 'Meals during the Event' => 'Catering', 'Facilities' => 'Equipment hire' };

    private static Id hippoEventRTId;
    private static Id completedHipoEventRTId;
    private static Id hippoAttendeeRTId;

    private static Map<Id, Medical_Event_vod__c> hippoIdMedEventMap;
    private static Map<Id, HCP_Account__c> hippoAccMap;
    private static Map<Id, Id> hippoEventMedEventMap;

    private static Map<Id, String> businessUnitMap;

    /**
     * @description Hippo Event after insert. Creates Medial event from Hippo Events
     * @author zoltan.nagy@veeva.com | 11-01-2022
     * @last modified on  : 05-08-2024
     * @last modified by  : daniel.magyar@veeva.com
     * @param newItems
     * @param newItemsMap
     **/
    public static void createMedicalEvents(List<SObject> newItems) {
        setBusinessUnitMap((List<Hippo_Event__c>) newItems);

        List<Medical_Event_vod__c> medEventsToInsert = new List<Medical_Event_vod__c>();
        List<Event_Attendee_vod__c> attendeesToInsert = new List<Event_Attendee_vod__c>();

        Map<Id, Medical_Event_vod__c> eventMap = new Map<Id, Medical_Event_vod__c>();

        for (Hippo_Event__c newItem : (List<Hippo_Event__c>) newItems) {
            if (COUNTRY_MAP.containsKey(newItem.Country_name__c) && newItem.Status__c == HIPPO_EVENT_APPROVED_STATUS && VALID_VIA_HIP_SUBTYPES.contains(newItem.VIA_HIP_Subtype__c)) {
                Medical_Event_vod__c medEvent = new Medical_Event_vod__c();
                populateMedEventInstance(newItem, medEvent, newItem.Country_name__c);
                populateMedEventCategory(newItem, medEvent);
                populateMedEventSubtype(newItem, medEvent);

                medEventsToInsert.add(medEvent);
            }
        }

        if (!medEventsToInsert.isEmpty()) {
            insert medEventsToInsert;
            System.debug('Inserted Medical Event: ' + medEventsToInsert);

            for (Hippo_Event__c newItem : (List<Hippo_Event__c>) newItems) {
                Medical_Event_vod__c medEvent = medEventsToInsert.get(0);
                createEPDEventExpenses(medEvent, newItem);
            }
        }

        medicalEventOwner((List<Hippo_Event__c>) newItems);
    }

    /**
     * @description Hippo Event after update. Updates MEdical Events following parent Hippo Event changes
     * @author zoltan.nagy@veeva.com | 11-01-2022
     * @last modified on  : 05-08-2024
     * @last modified by  : daniel.magyar@veeva.com
     * @param oldItemsMap
     * @param newItemsMap
     **/
    public static void updateMedicalEvents(Map<Id, SObject> oldItemsMap, Map<Id, SObject> newItemsMap) {
        setBusinessUnitMap((List<Hippo_Event__c>) newItemsMap.values());

        List<Medical_Event_vod__c> medEventsToUpdate = new List<Medical_Event_vod__c>();
        List<Id> hippoEventIds = new List<Id>();
        List<Id> hippoEventIdsForAttendees = new List<Id>();

        // Collect hippo event IDs to get the corresponding medical events
        for (Hippo_Event__c newItem : (List<Hippo_Event__c>) newItemsMap.values()) {
            String countryName = newItem.Country_name__c;

            // Fetch the old item for comparison
            Hippo_Event__c oldItem = (Hippo_Event__c) oldItemsMap.get(newItem.Id);

            // Check if the HIP subtype is valid
            if (!VALID_VIA_HIP_SUBTYPES.contains(newItem.VIA_HIP_Subtype__c)) {
                continue;
            }

            // Handle UK-specific logic, including the TERMINATED status
            if (UK_ONLY.equals(countryName)) {
                // Handle if Status__c changes to TERMINATED for UK
                if (newItem.Status__c == HIPPO_EVENT_TERMINATED_STATUS && oldItem.Status__c != HIPPO_EVENT_TERMINATED_STATUS) {
                    System.debug('Hippo Event ' + newItem.Id + ' has been TERMINATED in the UK.');

                    // Fetch the related Medical_Event_vod__c record
                    Medical_Event_vod__c relatedMedicalEvent = [
                        SELECT Id, VIA_Status__c, VIA_Hippo_Event__c, EPD_FR_MED_Event_Status__c, RecordTypeId
                        FROM Medical_Event_vod__c
                        WHERE VIA_Hippo_Event__c = :newItem.Id
                        LIMIT 1
                    ];

                    if (relatedMedicalEvent != null) {
                        // Copy the Status__c from Hippo_Event__c to VIA_Status__c in Medical_Event_vod__c
                        relatedMedicalEvent.VIA_Status__c = newItem.Status__c;
                        relatedMedicalEvent.EPD_FR_MED_Event_Status__c = newItem.Status_Formula__c;
                        relatedMedicalEvent.RecordTypeId = getCompletedHipoEventRTId(countryName);

                        medEventsToUpdate.add(relatedMedicalEvent);

                        System.debug('Copied Status__c from Hippo_Event__c to VIA_Status__c on Medical_Event_vod__c: ' + relatedMedicalEvent.Id);
                        System.debug('Updated RecordTypeId to completed for Medical_Event_vod__c: ' + relatedMedicalEvent.Id);
                    }
                    continue; // Skip further processing for TERMINATED events
                }

                // Handle Approved, Registered, or Terminated status changes for UK
                boolean isApproved = newItem.Status_Formula__c == Label.hippoApproved && oldItem.Status_Formula__c != Label.hippoApproved;
                boolean isRegistered = newItem.Status_Formula__c == Label.hippoRegistered && oldItem.Status_Formula__c != Label.hippoRegistered;
                boolean isTerminated = newItem.Status_Formula__c == Label.hippoTerminated && oldItem.Status_Formula__c != Label.hippoTerminated;

                if (!isApproved && !isRegistered && !isTerminated) {
                    continue; // Skip if not changing to Approved or Registered for UK
                }
            } else if (FRANCE_ONLY.equals(countryName)) {
                if (!(newItem.Status__c == HIPPO_EVENT_APPROVED_STATUS && oldItem.Status__c != HIPPO_EVENT_APPROVED_STATUS)) {
                    continue; // Skip if not changing to Approved for France
                }
            } else {
                if (newItem.Status__c != HIPPO_EVENT_APPROVED_STATUS && newItem.Status__c != HIPPO_EVENT_COMPLETED_STATUS && !COUNTRY_MAP.containsKey(countryName)) {
                    continue;
                }
            }

            // Process the events for attendees if it's moving out of draft
            if (newItem.Status__c == HIPPO_EVENT_APPROVED_STATUS && oldItem.Status__c != HIPPO_EVENT_APPROVED_STATUS) {
                hippoEventIdsForAttendees.add(newItem.Id);
            }

            // Check if any of the relevant fields changed
            for (String field : FIELD_MAPPING.keySet()) {
                if (newItem.get(field) != oldItem.get(field)) {
                    hippoEventIds.add(newItem.Id);
                    break;
                }
            }
        }

        if (!hippoEventIds.isEmpty()) {
            Map<Id, Medical_Event_vod__c> updateMap = getHippoIdMedEventMap(hippoEventIds);

            // If no Medical Event exists, it needs to be created
            for (Id hippoEventId : hippoEventIds) {
                if (!updateMap.containsKey(hippoEventId)) {
                    updateMap.put(hippoEventId, new Medical_Event_vod__c());
                }
            }

            // Populate and update medical events
            for (Id hippoId : updateMap.keySet()) {
                String countryName = (String) ((Hippo_Event__c) newItemsMap.get(hippoId)).get('Country_name__c');

                if (!COUNTRY_MAP.containsKey(countryName)) {
                    continue;
                }

                populateMedEventInstance((Hippo_Event__c) newItemsMap.get(hippoId), updateMap.get(hippoId), countryName);
                populateMedEventCategory((Hippo_Event__c) newItemsMap.get(hippoId), updateMap.get(hippoId));
                populateMedEventSubtype((Hippo_Event__c) newItemsMap.get(hippoId), updateMap.get(hippoId));
                medEventsToUpdate.add(updateMap.get(hippoId));
            }
        }

        if (!medEventsToUpdate.isEmpty()) {
            upsert medEventsToUpdate;
            medicalEventOwner((List<Hippo_Event__c>) newItemsMap.values());

            for (Medical_Event_vod__c medEvent : medEventsToUpdate) {
                Hippo_Event__c hippoEvent = (Hippo_Event__c) newItemsMap.get(medEvent.VIA_Hippo_Event__c);
                createEPDEventExpenses(medEvent, hippoEvent);
            }
        }

        // The attendees need to be pushed down to the Medical events for all Hippo Events that just left the draft status
        if (!hippoEventIdsForAttendees.isEmpty()) {
            Map<Id, Event_HCP__c> eventHCPMap = new Map<Id, Event_HCP__c>([SELECT Id, HCP_Account__c, Event__c, Event__r.VIA_HIP_Subtype__c FROM Event_HCP__c WHERE Event__c IN :hippoEventIdsForAttendees]);
            createMedicalEventAttendees(eventHCPMap);
        }
    }

    /**
     * @description Event_HCP after insert. Creates Event Attendes form each newly created hippo Event HCP record
     * @author zoltan.nagy@veeva.com | 11-01-2022
     * @param newItemsMap
     * @last modified on  : 05-08-2024
     * @last modified by  : daniel.magyar@veeva.com
     **/
    public static void createMedicalEventAttendees(Map<Id, SObject> newItemsMap) {
        List<Event_Attendee_vod__c> attendeesToInsert = new List<Event_Attendee_vod__c>();

        Map<Id, HCP_Account__c> accountMap = getHippoAccMap((Map<Id, Event_HCP__c>) newItemsMap);
        Map<Id, Id> eventMap = getHippoEventMedEventMap((Map<Id, Event_HCP__c>) newItemsMap);

        Set<Id> hippoEventIds = new Set<Id>();
        Map<Id, String> hippoEventIdCountryNameMap = new Map<Id, String>();

        for (Event_HCP__c eventHCP : (List<Event_HCP__c>) newItemsMap.values()) {
            if (String.isNotBlank(eventHCP.Event__c)) {
                hippoEventIds.add(eventHCP.Event__c);
            }
        }

        if (!hippoEventIds.isEmpty()) {
            hippoEventIdCountryNameMap = getHippoEventIdCountryNameMap(hippoEventIds);
        }

        for (Event_HCP__c eventHCP : (List<Event_HCP__c>) newItemsMap.values()) {
            if (!hippoEventIdCountryNameMap.containsKey(eventHCP.Event__c)) {
                continue;
            }

            String countryName = hippoEventIdCountryNameMap.get(eventHCP.Event__c);

            System.debug('COUNTRY NAME : ' + countryName);

            if (!HIPPO_EVENT_RT_NAME_MAP.containsKey(countryName)) {
                continue;
            }

            Id rtId = getHippoAttendeeRTId(HIPPO_ATTENDEE_RT_NAME);

            if (!accountMap.containsKey(eventHCP.HCP_Account__c) || !eventMap.containsKey(eventHCP.Event__c)) {
                continue;
            }

            Event_Attendee_vod__c eventAttendee = new Event_Attendee_vod__c(
                Account_vod__c = (accountMap.get(eventHCP.HCP_Account__c)).Account__c,
                Medical_Event_vod__c = eventMap.get(eventHCP.Event__c),
                RecordTypeId = rtId,
                VIA_Event_HCP__c = eventHCP.Id,
                VIA_Speaker__c = String.isNotBlank((accountMap.get(eventHCP.HCP_Account__c)).Current_FMV_Assessment__c),
                VIA_HIPPO_Event_Attendee__c = true,
                Expense_Attendee_Type_vod__c = 'HCP',
                Status_vod__c = 'Invited'
            );

            attendeesToInsert.add(eventAttendee);
        }

        if (!attendeesToInsert.isEmpty()) {
            insert attendeesToInsert;
        }
    }

    /**
     * @description Hippo_Interaction__c after insert. Creates Event Attendes frm each newly created Hippo Interaction record
     * @author daniel.magyar@veeva.com | 16-12-2023
     * @last modified on  : 05-08-2024
     * @last modified by  : daniel.magyar@veeva.com
     * @param newItemsMap
     **/
    public static void insertMedicalEventAttendeesFromInteraction(Map<Id, SObject> newItemsMap) {
        List<Event_Attendee_vod__c> attendeesToInsert = new List<Event_Attendee_vod__c>();
        List<Medical_Event_vod__c> medEventsToUpdate = new List<Medical_Event_vod__c>();

        Map<Id, HCP_Account__c> accountMap = getHippoAccMapFromInteraction((Map<Id, Hippo_Interaction__c>) newItemsMap);
        Map<Id, Id> eventMap = getHippoEventMedEventMapFromInteraction((Map<Id, Hippo_Interaction__c>) newItemsMap);

        Set<Id> hippoEventIds = new Set<Id>();
        Map<Id, String> hippoEventIdCountryNameMap = new Map<Id, String>();

        for (Hippo_Interaction__c interaction : (List<Hippo_Interaction__c>) newItemsMap.values()) {
            if (String.isNotBlank(interaction.Hippo_Event__c)) {
                hippoEventIds.add(interaction.Hippo_Event__c);
            }
        }

        if (!hippoEventIds.isEmpty()) {
            hippoEventIdCountryNameMap = getHippoEventIdCountryNameMap(hippoEventIds);
        }

        for (Hippo_Interaction__c interaction : (List<Hippo_Interaction__c>) newItemsMap.values()) {
            if (!hippoEventIdCountryNameMap.containsKey(interaction.Hippo_Event__c)) {
                continue;
            }

            String countryName = hippoEventIdCountryNameMap.get(interaction.Hippo_Event__c);

            if (!FRANCE_ONLY.equals(countryName) && !UK_ONLY.equals(countryName)) {
                continue;
            }

            if (!HIPPO_EVENT_RT_NAME_MAP.containsKey(countryName)) {
                continue;
            }

            Id rtId = getHippoAttendeeRTId(HIPPO_ATTENDEE_RT_NAME);

            if (!accountMap.containsKey(interaction.HCP_Account__c) || !eventMap.containsKey(interaction.Hippo_Event__c)) {
                continue;
            }

            if (accountMap.get(interaction.HCP_Account__c).Account__c == null) {
                System.debug('Skipping because HCP_Account__c has no related Account__c.');
                continue;
            }

            if (interaction.Status__c == 'Approved') {
                Event_Attendee_vod__c eventAttendee = new Event_Attendee_vod__c(
                    Account_vod__c = (accountMap.get(interaction.HCP_Account__c)).Account__c,
                    Medical_Event_vod__c = eventMap.get(interaction.Hippo_Event__c),
                    RecordTypeId = rtId,
                    Status_vod__c = 'Invited',
                    VIA_Hippo_Interaction__c = interaction.id,
                    VIA_Speaker__c = String.isNotBlank((accountMap.get(interaction.HCP_Account__c)).Current_FMV_Assessment__c),
                    VIA_HIPPO_Event_Attendee__c = true,
                    Expense_Attendee_Type_vod__c = 'HCP'
                );

                eventAttendee.EPD_FR_MED_Speaker__c = isSpeakerInteraction(interaction);
                eventAttendee.Incurred_Expense_vod__c = (interaction.Type__c == 'Educational Support' || interaction.Type__c == 'Engagement');

                attendeesToInsert.add(eventAttendee);

                if (interaction.Travel_Cost_Calculation__c > 0) {
                    Medical_Event_vod__c medEvent = new Medical_Event_vod__c(Id = eventAttendee.MedicaL_Event_vod__c, MYL_FR_Paid_Speaker__c = 'Yes');
                    medEventsToUpdate.add(medEvent);
                }
            }
        }

        if (!attendeesToInsert.isEmpty()) {
            insert attendeesToInsert;
        }

        createEPDEventExpensesFromInteraction((Map<Id, Hippo_Interaction__c>) newItemsMap, attendeesToInsert);

        if (!medEventsToUpdate.isEmpty()) {
            update medEventsToUpdate;
        }
    }

    /**
     * @description Hippo_Interaction__c after update. Creates or updates Event Attendees from each created or updated Hippo Interaction record
     * @author daniel.magyar@veeva.com | 16-12-2023
     * @last modified on  : 05-08-2024
     * @last modified by  : daniel.magyar@veeva.com
     * @param newItemsMap
     **/
    public static void upsertMedicalEventAttendeesFromInteraction(Map<Id, SObject> oldItemsMap, Map<Id, SObject> newItemsMap) {
        System.debug('Entering upsertMedicalEventAttendeesFromInteraction');
        List<Event_Attendee_vod__c> attendeesToUpsert = new List<Event_Attendee_vod__c>();
        List<Medical_Event_vod__c> medEventsToUpdate = new List<Medical_Event_vod__c>();

        System.debug('Retrieving account and event mappings');
        Map<Id, HCP_Account__c> accountMap = getHippoAccMapFromInteraction((Map<Id, Hippo_Interaction__c>) newItemsMap);
        System.debug('Account map retrieved: ' + accountMap);
        Map<Id, Id> eventMap = getHippoEventMedEventMapFromInteraction((Map<Id, Hippo_Interaction__c>) newItemsMap);
        System.debug('Event map retrieved: ' + eventMap);

        Set<Id> hippoEventIds = new Set<Id>();
        Map<Id, String> hippoEventIdCountryNameMap = new Map<Id, String>();

        for (Hippo_Interaction__c interaction : (List<Hippo_Interaction__c>) newItemsMap.values()) {
            if (String.isNotBlank(interaction.Hippo_Event__c)) {
                hippoEventIds.add(interaction.Hippo_Event__c);
                System.debug('Added Hippo Event ID: ' + interaction.Hippo_Event__c);
            }
        }

        if (!hippoEventIds.isEmpty()) {
            hippoEventIdCountryNameMap = getHippoEventIdCountryNameMap(hippoEventIds);
            System.debug('Country name map retrieved: ' + hippoEventIdCountryNameMap);
        }

        Set<Id> interactionIds = new Set<Id>();
        for (Hippo_Interaction__c interaction : (List<Hippo_Interaction__c>) newItemsMap.values()) {
            interactionIds.add(interaction.Id);
            System.debug('Added Interaction ID: ' + interaction.Id);
        }

        Map<Id, Event_Attendee_vod__c> existingAttendeesMap = new Map<Id, Event_Attendee_vod__c>();
        for (Event_Attendee_vod__c attendee : [SELECT Id, Status_vod__c, VIA_Hippo_Interaction__c, Medical_Event_vod__c FROM Event_Attendee_vod__c WHERE VIA_Hippo_Interaction__c IN :interactionIds]) {
            existingAttendeesMap.put(attendee.VIA_Hippo_Interaction__c, attendee);
            System.debug('Added attendee to map: ' + attendee.Id);
        }

        for (Hippo_Interaction__c interaction : (List<Hippo_Interaction__c>) newItemsMap.values()) {
            if (!hippoEventIdCountryNameMap.containsKey(interaction.Hippo_Event__c)) {
                continue;
                System.debug('Skipping interaction with unknown country name: ' + interaction.Id);
            }

            String countryName = hippoEventIdCountryNameMap.get(interaction.Hippo_Event__c);
            System.debug('Country Name for Hippo Event ID ' + interaction.Hippo_Event__c + ': ' + countryName);

            if (!FRANCE_ONLY.equals(countryName) && !UK_ONLY.equals(countryName)) {
                continue;
                System.debug('Country Name for Hippo Event ID ' + interaction.Hippo_Event__c + ': ' + countryName);
            }

            if (!HIPPO_EVENT_RT_NAME_MAP.containsKey(countryName)) {
                System.debug('Record Type Name exists for country: ' + countryName);
                continue;
                System.debug('Record Type Name does not exist for country: ' + countryName);
            }

            System.debug('Before getHippoAttendeeRTId, completedHipoEventRTId=' + completedHipoEventRTId);
            Id rtId = getHippoAttendeeRTId(HIPPO_ATTENDEE_RT_NAME);
            System.debug('Record Type ID for Hippo Attendee Record Type: ' + rtId);
            System.debug('After getHippoAttendeeRTId, completedHipoEventRTId=' + completedHipoEventRTId);

            if (!accountMap.containsKey(interaction.HCP_Account__c) || !eventMap.containsKey(interaction.Hippo_Event__c)) {
                continue;
                System.debug('Skipping interaction due to missing account or event mapping: ' + interaction.Id);
            }

            if (accountMap.get(interaction.HCP_Account__c).Account__c == null) {
                System.debug('Skipping because HCP_Account__c has no related Account__c.');
                continue;
            }

            Hippo_Interaction__c oldInteraction = oldItemsMap != null ? (Hippo_Interaction__c) oldItemsMap.get(interaction.Id) : null;
            Event_Attendee_vod__c eventAttendee = existingAttendeesMap.get(interaction.Id);

            if (oldInteraction == null || (oldInteraction != null && interaction.Status__c != oldInteraction.Status__c)) {
                String attendeeStatus;
                if (interaction.Status__c == 'Approved') {
                    attendeeStatus = 'Invited';
                } else if (INTERACTION_UPDATE_STATUSES.contains(interaction.Status__c)) {
                    attendeeStatus = interaction.Status__c;
                } else {
                    continue;
                    System.debug('Skipping interaction due to unsupported status change: ' + interaction.Id);
                }
                System.debug('Interaction ID: ' + interaction.Id + ', Status Change to: ' + attendeeStatus);

                System.debug('interaction: ' + interaction);
                System.debug('interaction.HCP_Account__c: ' + interaction.HCP_Account__c);
                System.debug('accountMap contains key?: ' + accountMap.containsKey(interaction.HCP_Account__c));
                System.debug('Full record from accountMap (HCP_Account__c): ' + accountMap.get(interaction.HCP_Account__c));
                System.debug('>>> Attempting to set Account_vod__c from accountMap: ' + accountMap.get(interaction.HCP_Account__c).Account__c);
                if (eventAttendee == null) {
                    eventAttendee = new Event_Attendee_vod__c(
                        Account_vod__c = (accountMap.get(interaction.HCP_Account__c)).Account__c,
                        Medical_Event_vod__c = eventMap.get(interaction.Hippo_Event__c),
                        RecordTypeId = rtId,
                        VIA_Hippo_Interaction__c = interaction.id,
                        VIA_Speaker__c = String.isNotBlank((accountMap.get(interaction.HCP_Account__c)).Current_FMV_Assessment__c),
                        VIA_HIPPO_Event_Attendee__c = true,
                        Expense_Attendee_Type_vod__c = 'HCP'
                    );
                    eventAttendee.EPD_FR_MED_Speaker__c = isSpeakerInteraction(interaction);
                    eventAttendee.Incurred_Expense_vod__c = (interaction.Type__c == 'Educational Support' || interaction.Type__c == 'Engagement');
                } else {
                    eventAttendee.Status_vod__c = attendeeStatus;
                }

                attendeesToUpsert.add(eventAttendee);

                if (interaction.Travel_Cost_Calculation__c > 0) {
                    Medical_Event_vod__c medEvent = new Medical_Event_vod__c(Id = eventAttendee.Medical_Event_vod__c, MYL_FR_Paid_Speaker__c = 'Yes');
                    medEventsToUpdate.add(medEvent);
                }
            }
        }

        if (!attendeesToUpsert.isEmpty()) {
            System.debug('Attendees to upsert: ' + attendeesToUpsert);
            upsert attendeesToUpsert;
            System.debug('Attendees successfully upserted');
        }

        createEPDEventExpensesFromInteraction((Map<Id, Hippo_Interaction__c>) newItemsMap, attendeesToUpsert);
        System.debug('EPD expenses created successfully');

        if (!medEventsToUpdate.isEmpty()) {
            update medEventsToUpdate;
            System.debug('Medical events updated successfully');
        }
    }

    /**
     * @description returns the map of hippo hcp account Ids and Veeva Ids for the given Hippo Interaction instances
     * @author daniel.magyar@veeva.com | 09-12-2023
     * @param newItemsMap
     * @return Map<Id, Id>
     **/
    private static Map<Id, HCP_Account__c> getHippoAccMapFromInteraction(Map<Id, Hippo_Interaction__c> newItemsMap) {
        List<Id> hcpAccountsToQuery = new List<Id>();

        if (hippoAccMap == null) {
            hippoAccMap = new Map<Id, HCP_Account__c>();
        }

        for (Hippo_Interaction__c newItem : newItemsMap.values()) {
            if (String.isNotBlank(newItem.HCP_Account__c) && !hippoAccMap.containsKey(newItem.HCP_Account__c)) {
                hcpAccountsToQuery.add(newItem.HCP_Account__c);
            }
        }

        if (!hcpAccountsToQuery.isEmpty()) {
            for (HCP_Account__c hcpAcc : [SELECT Id, Account__c, Current_FMV_Assessment__c FROM HCP_Account__c WHERE Id IN :hcpAccountsToQuery]) {
                hippoAccMap.put(hcpAcc.Id, hcpAcc);
            }
        }

        return hippoAccMap;
    }

    /**
     * @description returns the map of hippo event ids and the corresponding medical event ids for the given Hippo Interaction records
     * @author daniel.magyar@veeva.com | 09-12-2023
     * @param newItemsMap
     * @return Map<Id, Id>
     **/
    private static Map<Id, Id> getHippoEventMedEventMapFromInteraction(Map<Id, Hippo_Interaction__c> newItemsMap) {
        List<Id> hippoEventIdsToQuery = new List<Id>();

        if (hippoEventMedEventMap == null) {
            hippoEventMedEventMap = new Map<Id, Id>();
        }

        for (Hippo_Interaction__c newItem : newItemsMap.values()) {
            if (String.isNotBlank(newItem.Hippo_Event__c) && !hippoEventMedEventMap.containsKey(newItem.Hippo_Event__c) && !hippoEventIdsToQuery.contains(newItem.Hippo_Event__c)) {
                hippoEventIdsToQuery.add(newItem.Hippo_Event__c);
            }
        }

        if (!hippoEventIdsToQuery.isEmpty()) {
            for (Medical_Event_vod__c medEvent : [SELECT Id, VIA_Hippo_Event__c FROM Medical_Event_vod__c WHERE VIA_Hippo_Event__c IN :hippoEventIdsToQuery]) {
                hippoEventMedEventMap.put(medEvent.VIA_Hippo_Event__c, medEvent.Id);
            }
        }

        return hippoEventMedEventMap;
    }

    /**
     * @description getter for hippo events country names
     * @author laszlo.fodor@veeva.com | 08-17-2023
     * @param hippoEventIds
     * @return Map<Id, String>
     **/
    private static Map<Id, String> getHippoEventIdCountryNameMap(Set<Id> hippoEventIds) {
        Map<Id, String> retVal = new Map<Id, String>();

        for (Hippo_Event__c hippoEvent : [SELECT Id, Country_name__c FROM Hippo_Event__c WHERE Id IN :hippoEventIds]) {
            retVal.put(hippoEvent.Id, hippoEvent.Country_name__c);
        }

        return retVal;
    }

    /**
     * @description Delete Event attendees folloowing Even HCP deletion
     * @author zoltan.nagy@veeva.com | 11-01-2022
     * @param oldItemsMap
     * @last modified on  : 01-04-2024
     * @last modified by  : zoltan.nagy@veeva.com
     **/
    public static void deleteMedicalEventAttendees(List<SObject> oldItems) {
        List<Event_Attendee_vod__c> eventAttendeesToDelete = new List<Event_Attendee_vod__c>();
        //daniel.magyar@veeva.com - new list to update Event_Attendee_vod__c in case of Event_HCP__c is deleted for France
        List<Event_Attendee_vod__c> eventAttendeesToUpdate = new List<Event_Attendee_vod__c>();
        //remains
        List<Id> eventHCPIDs = new List<Id>();

        for (SObject oldItem : oldItems) {
            eventHCPIDs.add(oldItem.Id);
        }

        Map<Id, String> getHippoEventIdCountryNameMap = new Map<Id, String>();

        for (Event_HCP__c eventHCP : [SELECT Id, Event__r.Country_name__c FROM Event_HCP__c WHERE Id IN :eventHCPIDs]) {
            getHippoEventIdCountryNameMap.put(eventHCP.Id, eventHCP.Event__r.Country_name__c);
        }

        //daniel.magyar@veeva.com - now there is an update for France, else Delete
        for (Event_Attendee_vod__c eventAttendee : [SELECT Id, VIA_Event_HCP__c FROM Event_Attendee_vod__c WHERE VIA_Event_HCP__c IN :eventHCPIDs]) {
            String countryName = getHippoEventIdCountryNameMap.get(eventAttendee.VIA_Event_HCP__c);
            if (countryName.equals(FRANCE_ONLY)) {
                eventAttendee.Status_vod__c = 'Cancelled';
                eventAttendeesToUpdate.add(eventAttendee);
            } else {
                eventAttendeesToDelete.add(eventAttendee);
            }
        }

        if (!eventAttendeesToUpdate.isEmpty()) {
            update eventAttendeesToUpdate;
        }

        if (!eventAttendeesToDelete.isEmpty()) {
            delete eventAttendeesToDelete;
        }
    }

    /**
     * @description returns the map of hippo hcp account Ids and Veeva Ids for the given Event HCP instances
     * @author zoltan.nagy@veeva.com | 11-01-2022
     * @param newItemsMap
     * @return Map<Id, Id>
     **/
    private static Map<Id, HCP_Account__c> getHippoAccMap(Map<Id, Event_HCP__c> newItemsMap) {
        List<Id> hcpAccountsToQuery = new List<Id>();

        if (hippoAccMap == null) {
            hippoAccMap = new Map<Id, HCP_Account__c>();
        }

        for (Event_HCP__c newItem : newItemsMap.values()) {
            if (String.isNotBlank(newItem.HCP_Account__c) && !hippoAccMap.containsKey(newItem.HCP_Account__c)) {
                hcpAccountsToQuery.add(newItem.HCP_Account__c);
            }
        }

        if (!hcpAccountsToQuery.isEmpty()) {
            for (HCP_Account__c hcpAcc : [SELECT Id, Account__c, Current_FMV_Assessment__c FROM HCP_Account__c WHERE Id IN :hcpAccountsToQuery]) {
                hippoAccMap.put(hcpAcc.Id, hcpAcc);
            }
        }

        return hippoAccMap;
    }

    /**
     * @description returns the map of hippo event ids and the corresponding medical event ids for the givent event_hcp records
     * @author zoltan.nagy@veeva.com | 11-01-2022
     * @param newItemsMap
     * @return Map<Id, Id>
     **/
    private static Map<Id, Id> getHippoEventMedEventMap(Map<Id, Event_HCP__c> newItemsMap) {
        List<Id> hippoEventIdsToQuery = new List<Id>();

        if (hippoEventMedEventMap == null) {
            hippoEventMedEventMap = new Map<Id, Id>();
        }

        for (Event_HCP__c newItem : newItemsMap.values()) {
            if (String.isNotBlank(newItem.Event__c) && !hippoEventMedEventMap.containsKey(newItem.Event__c) && !hippoEventIdsToQuery.contains(newItem.Event__c)) {
                hippoEventIdsToQuery.add(newItem.Event__c);
            }
        }

        if (!hippoEventIdsToQuery.isEmpty()) {
            for (Medical_Event_vod__c medEvent : [SELECT Id, VIA_Hippo_Event__c FROM Medical_Event_vod__c WHERE VIA_Hippo_Event__c IN :hippoEventIdsToQuery]) {
                hippoEventMedEventMap.put(medEvent.VIA_Hippo_Event__c, medEvent.Id);
            }
        }

        return hippoEventMedEventMap;
    }

    /**
     * @description getter for the Medical Event's hippo event record type
     * @author zoltan.nagy@veeva.com | 11-01-2022
     * @return String
     **/
    private static String getHippoEventRTId(String country) {
        String recordTypeName = HIPPO_EVENT_RT_NAME_MAP.get(country);

        if (hippoEventRTId == null) {
            hippoEventRTId = Schema.getGlobalDescribe().get('Medical_Event_vod__c').getDescribe().getRecordTypeInfosByDeveloperName().get(recordTypeName).getRecordTypeId();
        }

        return hippoEventRTId;
    }

    /**
     * @description getter for the Medical Event's completed hippo event record type
     * @author zoltan.nagy@veeva.com | 11-01-2022
     * @return String
     **/
    private static String getCompletedHipoEventRTId(String country) {
        String completedRecTypeName = HIPPO_COMPLETED_EVENT_RT_NAME_MAP.get(country);

        if (completedHipoEventRTId == null) {
            completedHipoEventRTId = Schema.getGlobalDescribe().get('Medical_Event_vod__c').getDescribe().getRecordTypeInfosByDeveloperName().get(completedRecTypeName).getRecordTypeId();
        }

        return completedHipoEventRTId;
    }

    /**
     * @description getter for the Event Attendee record type id for Hippo Attendees
     * @author zoltan.nagy@veeva.com | 11-01-2022
     * @return String
     **/
    private static String getHippoAttendeeRTId(String recTypeName) {
        if (completedHipoEventRTId == null) {
            completedHipoEventRTId = Schema.getGlobalDescribe().get('Event_Attendee_vod__c').getDescribe().getRecordTypeInfosByDeveloperName().get(recTypeName).getRecordTypeId();
            System.debug('Completed Hippo Event RT ID set: ' + completedHipoEventRTId);
        }

        return completedHipoEventRTId;
    }

    /**
     * @description populates med event instance based on the given hippo event instance and the field mapping.
     * @author zoltan.nagy@veeva.com | 11-01-2022
     * @param hippoEvent
     * @param medEvent
     * @last modified on  : 01-04-2024
     * @last modified by  : zoltan.nagy@veeva.com
     **/
    private static void populateMedEventInstance(Hippo_Event__c hippoEvent, Medical_Event_vod__c medEvent, String countryName) {
        for (String hippoField : FIELD_MAPPING.keySet()) {
            System.debug('Processing FIELD_MAPPING: ' + hippoField);
            if (String.isNotBlank(FIELD_MAPPING.get(hippoField))) {
                String medEventField = FIELD_MAPPING.get(hippoField);
                medEvent.put(medEventField, hippoEvent.get(hippoField));
                System.debug('Mapped ' + hippoField + ' to ' + medEventField);
                System.debug('Mapped ' + hippoField + ' to ' + medEventField + (hippoField.equals('Event_subtype__c') ? ' (Event_subtype__c populated with: ' + hippoEvent.get(hippoField) + ')' : ''));
            }
        }
        //daniel.magyar@veeva.com - if France, add additional fields
        if (countryName.equals(FRANCE_ONLY)) {
            for (String hippoField : FIELD_MAPPING_FR.keySet()) {
                System.debug('Processing FIELD_MAPPING_FR in addition in case of countryName = France: ' + hippoField);
                if (String.isNotBlank(FIELD_MAPPING_FR.get(hippoField))) {
                    String medEventField = FIELD_MAPPING_FR.get(hippoField);
                    medEvent.put(medEventField, hippoEvent.get(hippoField));
                    System.debug('Mapped ' + hippoField + ' to ' + medEventField + ' in case of France.');
                    System.debug('Mapped ' + hippoField + ' to ' + medEventField + (hippoField.equals('Event_subtype__c') ? ' (Event_subtype__c populated with: ' + hippoEvent.get(hippoField) + ')' : ''));
                }
            }

            //change status to Hippo approved
            if (hippoEvent.Status__c == 'Approved') {
                medEvent.put('VIA_Status__c', 'Hippo Approved');
                medEvent.put('EPD_FR_MED_Event_Status__c', 'Hippo approved');
            }
        } else if (countryName.equals(UK_ONLY)) {
            //daniel.magyar@veeva.com - UK requirements 05.10.2024
            for (String hippoField : FIELD_MAPPING_UK.keySet()) {
                System.debug('Processing FIELD_MAPPING_UK in addition in case of countryName = United Kingdom: ' + hippoField);
                if (String.isNotBlank(FIELD_MAPPING_UK.get(hippoField))) {
                    String medEventField = FIELD_MAPPING_UK.get(hippoField);
                    medEvent.put(medEventField, hippoEvent.get(hippoField));
                    System.debug('Mapped ' + hippoField + ' to ' + medEventField + ' in case of United Kingdom.');
                }

                // Update the VIA_Status__c based on Status_Formula__c values
                if (hippoEvent.Status_Formula__c == Label.hippoTerminated) {
                    medEvent.put('VIA_Status__c', 'Terminated');
                } else if (hippoEvent.Status_Formula__c == Label.hippoRegistered) {
                    medEvent.put('VIA_Status__c', 'Registered');
                } else if (hippoEvent.Status_Formula__c == Label.hippoApproved) {
                    medEvent.put('VIA_Status__c', 'Approved');
                }

                String location = hippoEvent.Event_venue__c + ', ' + hippoEvent.Address__c + ', ' + hippoEvent.City__c + ', ' + hippoEvent.zipcode__c + ', ' + hippoEvent.Country_name__c;
                if (location.length() > 255) {
                    location = location.substring(0, 255);
                }
                medEvent.Location__c = location;
                System.debug('Set Location__c for UK: ' + location);
            }
        }
        try {
            medEvent.Event_Type__c = getMedicalEvenTypeCalculated(hippoEvent);
            System.debug('Event_Type__c successfully set to: ' + medEvent.Event_Type__c);
        } catch (Exception e) {
            System.debug('Error setting Event_Type__c: ' + e.getMessage());
        }

        medEvent.VIA_Country_Code__c = COUNTRY_MAP.get(hippoEvent.Country_name__c);
        medEvent.RecordTypeId = hippoEvent.Status__c == 'Completed' ? getCompletedHipoEventRTId(countryName) : getHippoEventRTId(countryName);

        system.debug('med event: ' + medEvent);
    }

    /**
     * @description retrieves the Medical event needs to be updated, following hippo event changes
     * @author zoltan.nagy@veeva.com | 11-01-2022
     * @param hippoEventIds
     * @return Map<Id, Medical_Event_vod__c>
     **/
    private static Map<Id, Medical_Event_vod__c> getHippoIdMedEventMap(List<Id> hippoEventIds) {
        List<Id> idsToQuery = new List<Id>();

        if (hippoIdMedEventMap == null) {
            hippoIdMedEventMap = new Map<Id, Medical_Event_vod__c>();
        }

        for (Id hippoId : hippoEventIds) {
            if (!hippoIdMedEventMap.containsKey(hippoId)) {
                idsToQuery.add(hippoId);
            }
        }

        if (!idsToQuery.isEmpty()) {
            String queryFields = String.join(FIELD_MAPPING.values(), ',');
            String query = 'SELECT Id, MYL_Country_Code__c, RecordTypeId, ' + queryFields + ' FROM Medical_Event_vod__c WHERE VIA_Hippo_Event__c IN :idsToQuery';

            for (Medical_Event_vod__c medEvent : Database.query(query)) {
                hippoIdMedEventMap.put(medEvent.VIA_Hippo_Event__c, medEvent);
            }

            for (Id hippoId : hippoEventIds) {
                if (!hippoIdMedEventMap.containsKey(hippoId)) {
                    Medical_Event_vod__c medEvent = new Medical_Event_vod__c(VIA_Hippo_Event__c = hippoId);
                    hippoIdMedEventMap.put(hippoId, medEvent);
                }
            }
        }

        return hippoIdMedEventMap;
    }

    /**
     * @description populates the business unit map in a recursion safe manner
     * @author zoltan.nagy@veeva.com | 12-21-2023
     * @param newItems
     **/
    private static void setBusinessUnitMap(List<Hippo_Event__c> newItems) {
        if (businessUnitMap == null) {
            businessUnitMap = new Map<Id, String>();

            Set<Id> idsToQuery = new Set<Id>();

            for (Hippo_Event__c newItem : newItems) {
                if (String.isNotBlank(newItem.Business_Unit__c)) {
                    idsToQuery.add(newItem.Business_Unit__c);
                }
            }

            if (!idsToQuery.isEmpty()) {
                for (Hippo_Business_Unit__c bu : [SELECT Id, Name FROM Hippo_Business_Unit__c WHERE Id IN :idsToQuery]) {
                    businessUnitMap.put(bu.Id, bu.Name);
                }
            }
        }
    }

    /**
     * @description  retuers a medical event type value based on the parent hippo event Event_subtype and Business_unit values
     * @author zoltan.nagy@veeva.com | 12-21-2023
     * @param hippoEvent
     * @return String
     **/
    private static String getMedicalEvenTypeCalculated(Hippo_Event__c hippoEvent) {
        String retval = '';

        User createdByUser = [SELECT Id, Division, Title, Name FROM User WHERE Id = :hippoEvent.CreatedById];

        System.debug('Event Subtype: ' + hippoEvent.Event_subtype__c);
        System.debug('Division: ' + createdByUser.Division);
        System.debug('Title: ' + createdByUser.Title);
        System.debug('The running user for getMedicalEvenTypeCalculated is: ' + createdByUser.Name + ' ' + hippoEvent.CreatedById);

        Boolean eventTypeCase = (String.isNotBlank(hippoEvent.Event_subtype__c) && String.isNotBlank(createdByUser.Division) && String.isNotBlank(createdByUser.Title));
        System.debug('Event Type Case: ' + eventTypeCase);

        if (eventTypeCase && new List<String>{ 'RP Classic / RP Conference', 'RP Repetitive' }.contains(hippoEvent.Event_subtype__c) && new List<String>{ 'Prescription', 'Hospital' }.contains(createdByUser.Division) && new List<String>{ 'Rep', 'FLM', 'KAM' }.contains(createdByUser.Title)) {
            System.debug('Criteria for RPS met');
            retval = 'RPS';
        } else {
            System.debug('Criteria for RPS not met');
        }

        if (eventTypeCase && new List<String>{ 'Staff Classic', 'Staff Repetitive' }.contains(hippoEvent.Event_subtype__c) && new List<String>{ 'Prescription', 'Hospital' }.contains(createdByUser.Division) && new List<String>{ 'Rep', 'FLM', 'KAM' }.contains(createdByUser.Title)) {
            System.debug('Criteria for STAFF met');
            retval = 'STAFF';
        } else {
            System.debug('Criteria for STAFF not met');
        }

        if (eventTypeCase && hippoEvent.Event_subtype__c == 'RP Classic / RP Conference' && 'Pharmacy'.equals(createdByUser.Division) && new List<String>{ 'Rep', 'FLM', 'KAM' }.contains(createdByUser.Title)) {
            System.debug('Criteria for Conference met');
            retval = 'Conference';
        } else {
            System.debug('Criteria for Conference not met');
        }

        System.debug('Returned Event Type: ' + retval);
        return retval;
    }

    /**
     * @description decides if the given Hippo Interaction (attendee) is representing a speaker
     * @author zoltan.nagy@veeva.com | 12-22-2023
     * @param interaction
     * @return Boolean
     **/
    private static Boolean isSpeakerInteraction(Hippo_Interaction__c interaction) {
        return (interaction.Type__c == 'Engagement' && interaction.Service_type__c == 'Speaker Program') ? true : (interaction.Type__c == 'Educational Support' ? false : false);
    }

    /**
     * @description change Event Attendee User if Event Owner is changed
     * @author daniel.magyar@veeva.com | 01-15-2024
     * @param medEvents
     **/
    private static void medicalEventOwner(List<Hippo_Event__c> hippoEvents) {
        Map<Id, Medical_Event_vod__c> medEventMap = new Map<Id, Medical_Event_vod__c>();
        for (Medical_Event_vod__c medEvent : [SELECT Id, VIA_Hippo_Event__c, OwnerId FROM Medical_Event_vod__c WHERE VIA_Hippo_Event__c IN :hippoEvents]) {
            medEventMap.put(medEvent.VIA_Hippo_Event__c, medEvent);
        }
        List<Event_Attendee_vod__c> attendeesToUpsert = new List<Event_Attendee_vod__c>();
        Set<Id> medEventIds = new Set<Id>();
        for (Medical_Event_vod__c medEvent : medEventMap.values()) {
            medEventIds.add(medEvent.Id);
        }

        Map<Id, Event_Attendee_vod__c> existingAttendeesMap = new Map<Id, Event_Attendee_vod__c>();
        for (Event_Attendee_vod__c attendee : [SELECT Id, Medical_Event_vod__c FROM Event_Attendee_vod__c WHERE Medical_Event_vod__c IN :medEventIds AND Expense_Attendee_Type_vod__c = 'SYSEMP']) {
            existingAttendeesMap.put(attendee.Medical_Event_vod__c, attendee);
        }

        for (Hippo_Event__c hippoEvent : hippoEvents) {
            if (hippoEvent.Country_name__c == FRANCE_ONLY || hippoEvent.Country_name__c == UK_ONLY) {
                Medical_Event_vod__c medEvent = medEventMap.get(hippoEvent.Id);
                if (medEvent != null) {
                    Event_Attendee_vod__c existingOwner = existingAttendeesMap.get(medEvent.Id);
                    if (existingOwner == null) {
                        existingOwner = new Event_Attendee_vod__c(User_vod__c = hippoEvent.OwnerId, Expense_Attendee_Type_vod__c = 'SYSEMP', Status_vod__c = 'Invited', Medical_Event_vod__c = medEvent.Id);
                    }

                    existingOwner.User_vod__c = hippoEvent.OwnerId;
                    attendeesToUpsert.add(existingOwner);
                }
            }
        }

        if (!attendeesToUpsert.isEmpty()) {
            upsert attendeesToUpsert;
        }
    }

    /**
     * @description populate Medical_Event_vod__c.VIA_Medical_Event_Category__c field based on Hippo_Event__c.Channel__c for France
     * @author daniel.magyar@veeva.com | 04-11-2024
     * @param hippoEvent
     * @param medEvent
     **/
    private static void populateMedEventCategory(Hippo_Event__c hippoEvent, Medical_Event_vod__c medEvent) {
        String channel = hippoEvent.Channel__c;
        if (channel != null && hippoEvent.Country_name__c == FRANCE_ONLY) {
            if ('Face to face'.equals(channel)) {
                medEvent.VIA_Medical_Event_Category__c = 'Face to Face';
            } else if ('Webinar'.equals(channel)) {
                medEvent.VIA_Medical_Event_Category__c = 'Remote';
            } else if ('Live and Online'.equals(channel)) {
                medEvent.VIA_Medical_Event_Category__c = 'Hybrid';
            } else if ('N/A'.equals(channel)) {
                medEvent.VIA_Medical_Event_Category__c = 'N/A';
            }
        }
    }

    /**
     * @description populate Medical_Event_vod__c.EPD_FR_MED_Event_Subtype__c field based on Hippo_Event__c.Event_subtype__c for France
     * @author daniel.magyar@veeva.com | 01-16-2024
     * @param hippoEvent
     * @param medEvent
     **/
    private static void populateMedEventSubtype(Hippo_Event__c hippoEvent, Medical_Event_vod__c medEvent) {
        String eventSubtype = hippoEvent.Event_subtype__c;
        System.debug('Event Subtype: ' + eventSubtype);
        User createdByUser = [SELECT Division FROM User WHERE Id = :hippoEvent.CreatedById];
        System.debug('Division: ' + createdByUser.Division);

        if (eventSubtype != null && hippoEvent.Country_name__c == FRANCE_ONLY) {
            if ('RP Classic / RP Conference'.equals(eventSubtype)) {
                medEvent.EPD_FR_MED_Event_Subtype__c = 'Pharmacy'.equals(createdByUser.Division) ? 'Conference' : 'Classic';
                System.debug('Assigned Subtype: ' + medEvent.EPD_FR_MED_Event_Subtype__c);
            } else if ('RP Repetitive'.equals(eventSubtype)) {
                medEvent.EPD_FR_MED_Event_Subtype__c = 'RP Repetitive';
            } else if ('Staff Classic'.equals(eventSubtype)) {
                medEvent.EPD_FR_MED_Event_Subtype__c = 'STAFF';
            } else if ('Staff Repetitive'.equals(eventSubtype)) {
                medEvent.EPD_FR_MED_Event_Subtype__c = 'STAFF Repetitive';
            } else if ('NA / Other'.equals(eventSubtype)) {
                medEvent.EPD_FR_MED_Event_Subtype__c = 'NA / Other';
            }
        }
    }

    /**
     * @description create Medical_Event_vod__c.EPD_Event_Expense__c records based on Hippo_Event__c.Hippo_Event_Amount__c records for UK
     * @author daniel.magyar@veeva.com | 08-27-2024
     * @param hippoEvent
     * @param medEvent
     **/
    private static void createEPDEventExpenses(Medical_Event_vod__c medEvent, Hippo_Event__c hippoEvent) {
        System.debug('Processing Medical Event ID: ' + medEvent.Id);
        System.debug('Processing Hippo Event ID: ' + hippoEvent.Id);

        if (hippoEvent.Country_name__c != UK_ONLY) {
            return;
        }

        List<EPD_Event_Expense__c> expensesToInsert = new List<EPD_Event_Expense__c>();
        List<Hippo_Event_Amount__c> eventAmounts = [
            SELECT Cost__c, Currency__c, Label__c, Other_Label__c
            FROM Hippo_Event_Amount__c
            WHERE Event__c = :hippoEvent.Id
        ];

        for (Hippo_Event_Amount__c amount : eventAmounts) {
            EPD_Event_Expense__c expense = new EPD_Event_Expense__c();
            expense.EPD_Medical_Event__c = medEvent.Id;

            for (String hippoField : EVENT_AMOUNT_TO_EXPENSE_FIELD_MAPPING.keySet()) {
                String epdField = EVENT_AMOUNT_TO_EXPENSE_FIELD_MAPPING.get(hippoField);
                Object fieldValue = amount.get(hippoField);

                if (fieldValue != null) {
                    Schema.DescribeFieldResult fieldDescribe = Schema.SObjectType.EPD_Event_Expense__c.fields.getMap().get(epdField).getDescribe();

                    // Handle EPD_Type__c field specifically
                    if ('EPD_Type__c'.equals(epdField)) {
                        String originalLabel = String.valueOf(fieldValue);
                        String labelValue;

                        if (LABEL_TO_EPD_TYPE_MAPPING.containsKey(originalLabel)) {
                            labelValue = LABEL_TO_EPD_TYPE_MAPPING.get(originalLabel); // Use the mapped value
                            System.debug('Label found in mapping. Original Label: ' + originalLabel + ', Mapped Value: ' + labelValue);
                        } else if ('Other'.equals(originalLabel) && amount.Other_Label__c != null) {
                            labelValue = String.valueOf(amount.Other_Label__c);
                            System.debug('Label is "Other" and Other_Label__c is not null. Using Other_Label__c: ' + labelValue);
                        } else {
                            labelValue = originalLabel;
                            System.debug('Label not found in mapping and is not "Other" with non-null Other_Label__c. Using original Label: ' + originalLabel);
                        }

                        expense.put(epdField, labelValue);
                        System.debug('Setting EPD_Type__c to: ' + labelValue);
                    }
                    // Handle numeric types
                    else if (fieldDescribe.getType() == Schema.DisplayType.CURRENCY || fieldDescribe.getType() == Schema.DisplayType.DOUBLE || fieldDescribe.getType() == Schema.DisplayType.INTEGER) {
                        Decimal decimalValue = Decimal.valueOf(String.valueOf(fieldValue));
                        expense.put(epdField, decimalValue);
                        System.debug('Setting numeric value for Field: ' + epdField + ' Value: ' + decimalValue);
                    }
                    // Handle string types
                    else if (fieldDescribe.getType() == Schema.DisplayType.STRING) {
                        expense.put(epdField, String.valueOf(fieldValue));
                        System.debug('Setting string value for Field: ' + epdField + ' Value: ' + fieldValue);
                    }
                    // Handle other types
                    else {
                        expense.put(epdField, fieldValue);
                        System.debug('Setting value for Field: ' + epdField + ' Value: ' + fieldValue);
                    }
                }
            }
            expensesToInsert.add(expense);
        }

        if (!expensesToInsert.isEmpty()) {
            try {
                insert expensesToInsert;
                System.debug('Inserted expenses count: ' + expensesToInsert.size());
            } catch (DmlException e) {
                System.debug('Error inserting new expenses: ' + e.getMessage());
            }
        }
    }

    /**
     * @description create Medical_Event_vod__c.EPD_Event_Expense__c records based on
     *              Hippo_Interaction__c.Hippo_Interaction_Amount__c records for UK.
     *              Deduplicates records by checking existing EPD_Event_Expense__c
     *              in the database (and newly created within the same transaction).
     * @author
     * @last modified on  : 12-02-2025
     * @last modified by  : daniel.magyar@veeva.com
     * @param interactions  Map<Id, Hippo_Interaction__c> - all the new or updated Hippo_Interaction__c
     * @param attendees     List<Event_Attendee_vod__c>   - any newly created or updated Event_Attendee_vod__c
     *                                                           that references these interactions
     **/
    private static void createEPDEventExpensesFromInteraction(Map<Id, Hippo_Interaction__c> interactions, List<Event_Attendee_vod__c> attendees) {
        System.debug('>>> Entering createEPDEventExpensesFromInteraction');
        System.debug('>>> Number of Hippo_Interaction__c records passed in: ' + interactions.size());
        System.debug('>>> Number of Event_Attendee_vod__c records passed in: ' + attendees.size());

        // + 1. Filter for approved interactions only.
        Map<Id, Hippo_Interaction__c> approvedInteractions = new Map<Id, Hippo_Interaction__c>();
        for (Hippo_Interaction__c inter : interactions.values()) {
            if (inter.Status__c == 'Approved') {
                approvedInteractions.put(inter.Id, inter);
            } else {
                System.debug('Skipping interaction ' + inter.Id + ' because status is not Approved: ' + inter.Status__c);
            }
        }
        System.debug('>>> Number of approved interactions: ' + approvedInteractions.size());
        if (approvedInteractions.isEmpty()) {
            System.debug('>>> No approved interactions, exiting method.');
            return;
        }

        // + 2. Build a map from Interaction Id -> Attendee Id for approved interactions.
        Map<Id, Id> interactionIdToAttendeeIdMap = new Map<Id, Id>();
        for (Event_Attendee_vod__c attendee : attendees) {
            if (attendee.VIA_Hippo_Interaction__c != null && approvedInteractions.containsKey(attendee.VIA_Hippo_Interaction__c)) {
                interactionIdToAttendeeIdMap.put(attendee.VIA_Hippo_Interaction__c, attendee.Id);
            }
        }
        System.debug('>>> interactionIdToAttendeeIdMap size: ' + interactionIdToAttendeeIdMap.size());

        // + 3. Build a map from Interaction Id -> Medical_Event_vod__c from attendee data.
        Map<Id, Id> interactionIdToMedEventIdMap = new Map<Id, Id>();
        for (Event_Attendee_vod__c attendee : attendees) {
            if (attendee.VIA_Hippo_Interaction__c != null && approvedInteractions.containsKey(attendee.VIA_Hippo_Interaction__c)) {
                interactionIdToMedEventIdMap.put(attendee.VIA_Hippo_Interaction__c, attendee.Medical_Event_vod__c);
            }
        }
        System.debug('>>> interactionIdToMedEventIdMap size (from Attendees): ' + interactionIdToMedEventIdMap.size());

        // + 4. Collect Hippo_Event__c IDs from approved interactions.
        Set<Id> hippoEventIds = new Set<Id>();
        for (Hippo_Interaction__c inter : approvedInteractions.values()) {
            if (inter.Hippo_Event__c != null) {
                hippoEventIds.add(inter.Hippo_Event__c);
            }
        }
        System.debug('>>> Found Hippo_Event__c IDs: ' + hippoEventIds);

        // + 5. Query Hippo_Event__c records to get their Country_name__c.
        Map<Id, String> hippoEventIdToCountryNameMap = new Map<Id, String>();
        if (!hippoEventIds.isEmpty()) {
            for (Hippo_Event__c he : [SELECT Id, Country_name__c FROM Hippo_Event__c WHERE Id IN :hippoEventIds]) {
                hippoEventIdToCountryNameMap.put(he.Id, he.Country_name__c);
            }
        }
        System.debug('>>> hippoEventIdToCountryNameMap: ' + hippoEventIdToCountryNameMap);

        // + 6. Build a map of Interaction Id -> CountryName.
        Map<Id, String> interactionIdToCountryNameMap = new Map<Id, String>();
        for (Hippo_Interaction__c inter : approvedInteractions.values()) {
            if (inter.Hippo_Event__c != null) {
                String country = hippoEventIdToCountryNameMap.get(inter.Hippo_Event__c);
                interactionIdToCountryNameMap.put(inter.Id, country);
            }
        }
        System.debug('>>> interactionIdToCountryNameMap: ' + interactionIdToCountryNameMap);

        // + 7. Filter to only approved interactions that are in the UK.
        Set<Id> interactionIdsToProcess = new Set<Id>();
        for (Id interId : interactionIdToCountryNameMap.keySet()) {
            if (UK_ONLY.equals(interactionIdToCountryNameMap.get(interId))) {
                interactionIdsToProcess.add(interId);
            }
        }
        System.debug('>>> Approved UK interactionIdsToProcess: ' + interactionIdsToProcess);
        if (interactionIdsToProcess.isEmpty()) {
            System.debug('>>> No approved UK interactions to process for expenses. Exiting method.');
            return;
        }

        // + 8. For each approved UK interaction that lacks a Medical_Event mapping from attendee data,
        // attempt to fill it using existing Medical Events from the related Hippo_Event__c.
        for (Id interactionId : interactionIdsToProcess) {
            if (!interactionIdToMedEventIdMap.containsKey(interactionId)) {
                Hippo_Interaction__c interTemp = approvedInteractions.get(interactionId);
                if (interTemp != null && interTemp.Hippo_Event__c != null) {
                    Map<Id, Id> missingMedEventMap = getHippoEventMedEventMapFromInteraction(approvedInteractions); // Pass approved interactions if possible.
                    if (missingMedEventMap.containsKey(interTemp.Hippo_Event__c)) {
                        interactionIdToMedEventIdMap.put(interactionId, missingMedEventMap.get(interTemp.Hippo_Event__c));
                    }
                }
            }
        }
        System.debug('>>> Final interactionIdToMedEventIdMap: ' + interactionIdToMedEventIdMap);

        // + 9. Build a deduplication map keyed by (InteractionId + '_' + ExpenseType).
        Map<String, EPD_Event_Expense__c> existingExpenseMap = new Map<String, EPD_Event_Expense__c>();
        if (!interactionIdsToProcess.isEmpty()) {
            List<EPD_Event_Expense__c> existingExpenses = [
                SELECT Id, EPD_Medical_Event__c, EPD_Type__c, EPD_Planned_Cost__c, CurrencyIsoCode, VIA_Event_Attendee__c, VIA_Hippo_Interaction__c
                FROM EPD_Event_Expense__c
                WHERE VIA_Hippo_Interaction__c IN :interactionIdsToProcess
            ];
            for (EPD_Event_Expense__c exp : existingExpenses) {
                String key = exp.VIA_Hippo_Interaction__c + '_' + exp.EPD_Type__c;
                existingExpenseMap.put(key, exp);
            }
        }
        System.debug('>>> existingExpenseMap keys: ' + existingExpenseMap.keySet());

        // + 10. Query Hippo_Interaction_Amount__c records for these approved UK interactions.
        List<Hippo_Interaction_Amount__c> interactionAmounts = [
            SELECT Cost__c, Currency__c, Label__c, Other_Label__c, Interaction__c
            FROM Hippo_Interaction_Amount__c
            WHERE Interaction__c IN :interactionIdsToProcess
        ];
        System.debug('>>> Found ' + interactionAmounts.size() + ' Hippo_Interaction_Amount__c records for approved UK interactions');

        List<EPD_Event_Expense__c> expensesToUpsert = new List<EPD_Event_Expense__c>();

        // + 11. Iterate over each Interaction Amount record.
        for (Hippo_Interaction_Amount__c amount : interactionAmounts) {
            Id interactionId = amount.Interaction__c;
            Id medEventId = interactionIdToMedEventIdMap.get(interactionId);
            Id attendeeId = interactionIdToAttendeeIdMap.get(interactionId);
            Hippo_Interaction__c inter = approvedInteractions.get(interactionId);
            System.debug('>>> Processing amount for Interaction=' + interactionId + ', medEventId=' + medEventId + ', attendeeId=' + attendeeId + ', interaction=' + inter);
            if (medEventId != null && inter != null) {
                // Only process if the interaction is Approved (already filtered).
                // Determine the final expense type using Label__c or Other_Label__c.
                String originalLabel = String.valueOf(amount.Label__c);
                String finalLabel;
                if (LABEL_TO_EPD_TYPE_MAPPING.containsKey(originalLabel)) {
                    finalLabel = LABEL_TO_EPD_TYPE_MAPPING.get(originalLabel);
                } else if ('Other'.equals(originalLabel) && amount.Other_Label__c != null) {
                    finalLabel = String.valueOf(amount.Other_Label__c);
                } else {
                    finalLabel = originalLabel;
                }
                // Build a deduplication key: InteractionId + '_' + finalLabel.
                String expenseKey = interactionId + '_' + finalLabel;
                System.debug('>>> Built expense key: ' + expenseKey);
                // Check if an expense already exists for this key.
                if (existingExpenseMap.containsKey(expenseKey)) {
                    System.debug('>>> Found existing expense for key: ' + expenseKey + '. Updating it.');
                    EPD_Event_Expense__c existingExpense = existingExpenseMap.get(expenseKey);
                    existingExpense.EPD_Planned_Cost__c = (amount.Cost__c == null) ? 0 : amount.Cost__c;
                    existingExpense.CurrencyIsoCode = (amount.Currency__c == null) ? '' : amount.Currency__c;
                    existingExpense.EPD_Comments__c = inter.Type__c;
                    expensesToUpsert.add(existingExpense);
                } else {
                    System.debug('>>> No existing expense for key: ' + expenseKey + '. Creating new expense.');
                    EPD_Event_Expense__c newExpense = new EPD_Event_Expense__c();
                    newExpense.VIA_Hippo_Interaction__c = interactionId; // Tie directly to the Interaction.
                    newExpense.EPD_Medical_Event__c = medEventId;
                    newExpense.EPD_Type__c = finalLabel;
                    newExpense.EPD_Planned_Cost__c = (amount.Cost__c == null) ? 0 : amount.Cost__c;
                    newExpense.CurrencyIsoCode = (amount.Currency__c == null) ? '' : amount.Currency__c;
                    newExpense.EPD_Comments__c = inter.Type__c;
                    if (attendeeId != null) {
                        newExpense.VIA_Event_Attendee__c = attendeeId;
                    }
                    expensesToUpsert.add(newExpense);
                    // Record this new expense in the map.
                    existingExpenseMap.put(expenseKey, newExpense);
                }
            } else {
                System.debug('>>> Skipping expense creation because medEventId or interaction is null for Interaction: ' + interactionId);
            }
        }

        // + 12. Upsert the expense records.
        if (!expensesToUpsert.isEmpty()) {
            System.debug('>>> Upserting ' + expensesToUpsert.size() + ' EPD_Event_Expense__c records.');
            try {
                upsert expensesToUpsert;
            } catch (DmlException e) {
                System.debug('Error upserting expenses: ' + e.getMessage());
            }
        } else {
            System.debug('>>> No EPD_Event_Expense__c records to upsert (expensesToUpsert is empty).');
        }
    }

    /**
     * @description Returns a unique key that identifies an EPD_Event_Expense__c
     *              based on critical fields:
     *              - Medical Event
     *              - Expense Type
     *              - Planned Cost
     *              - Currency Iso
     *              - Event Attendee (if applicable)
     * @author daniel.magyar@veeva.com
     * @param medEventId  Id - the associated Medical_Event_vod__c
     * @param expenseType String - the EPD_Type__c
     * @param cost        Decimal - the EPD_Planned_Cost__c
     * @param currencyIso String - the CurrencyIsoCode
     * @param attendeeId  Id - the VIA_Event_Attendee__c, if any
     * @return A concatenated string key to detect duplicates
     **/
    private static String buildExpenseKey(Id medEventId, String expenseType, Decimal cost, String currencyIso, Id attendeeId) {
        // Convert null to blank
        String safeMedEventId = (medEventId == null) ? '' : String.valueOf(medEventId);
        String safeType = (expenseType == null) ? '' : expenseType;
        String safeCost = (cost == null) ? '' : String.valueOf(cost);
        String safeCurrency = (currencyIso == null) ? '' : currencyIso;
        String safeAttendeeId = (attendeeId == null) ? '' : String.valueOf(attendeeId);

        return safeMedEventId + '|' + safeType + '|' + safeCost + '|' + safeCurrency + '|' + safeAttendeeId;
    }

    /**
     * @description Check if every attendee attended has a call submitted - UK Only
     * @author daniel.magyar@veeva.com | 09-09-2024
     * @param newItems
     **/
    public static void checkAttendeeCallSubmission(List<SObject> newItems, Map<Id, SObject> oldItemsMap) {
        System.debug('Entering checkAttendeeCallSubmission');

        List<Medical_Event_vod__c> medEvents = (List<Medical_Event_vod__c>) newItems;
        System.debug('Number of Medical Events to process: ' + medEvents.size());

        for (Medical_Event_vod__c medEvent : medEvents) {
            // Get the old version of the record
            Medical_Event_vod__c oldMedEvent = (Medical_Event_vod__c) oldItemsMap.get(medEvent.Id);

            System.debug('Processing Medical Event: ' + medEvent.Id + ' with MYL_Country_Code__c: ' + medEvent.MYL_Country_Code__c + ' and with VIA_Approval_Status__c: ' + medEvent.VIA_Approval_Status__c);

            // Check if the country is UK and VIA_Approval_Status__c has changed
            if ((medEvent.MYL_Country_Code__c != 'UK' || oldMedEvent == null || medEvent.VIA_Approval_Status__c == oldMedEvent.VIA_Approval_Status__c) || (medEvent.VIA_Approval_Status__c == 'Rejected' || medEvent.VIA_Approval_Status__c == 'Recalled')) {
                System.debug('Skipping Medical Event: ' + medEvent.Id + ' because either it is not in the UK, VIA_Approval_Status__c did not change, or it is Rejected/Recalled');
                continue;
            }

            List<Event_Attendee_vod__c> attendees = [
                SELECT Id, Account_vod__c, Account_vod__r.Name
                FROM Event_Attendee_vod__c
                WHERE Medical_Event_vod__c = :medEvent.Id AND Status_vod__c = 'Attended'
            ];

            System.debug('Number of attendees with Status = Attended for Medical Event ' + medEvent.Id + ': ' + attendees.size());

            if (attendees.isEmpty()) {
                System.debug('No attendees found with Status = Attended for Medical Event: ' + medEvent.Id);
                continue;
            }

            // Boolean to check if every attendee has a submitted call
            Boolean allCallsSubmitted = true;
            List<String> missingCallAttendees = new List<String>();

            for (Event_Attendee_vod__c attendee : attendees) {
                System.debug('Checking attendee: ' + attendee.Id + ' for submitted calls');

                List<Call2_vod__c> relatedCalls = [
                    SELECT Id
                    FROM Call2_vod__c
                    WHERE Account_vod__c = :attendee.Account_vod__c AND Medical_Event_vod__c = :medEvent.Id AND Status_vod__c = 'Submitted_vod'
                ];

                System.debug('Number of submitted calls found for attendee ' + attendee.Id + ': ' + relatedCalls.size());

                // If no submitted call is found for this attendee, mark it as missing
                if (relatedCalls.isEmpty()) {
                    System.debug('No submitted calls found for attendee: ' + attendee.Id);
                    allCallsSubmitted = false;
                    missingCallAttendees.add(attendee.Account_vod__r.Name);
                }
            }

            if (!allCallsSubmitted) {
                String missingAttendeesString = String.join(missingCallAttendees, ', ');
                System.debug('Not all calls are submitted. Missing calls for attendees: ' + missingAttendeesString);
                medEvent.addError('Not all attendees have submitted calls. Missing calls for these attendees: ' + missingAttendeesString);
            } else {
                System.debug('All calls are submitted for Medical Event: ' + medEvent.Id);
            }
        }
    }
}
