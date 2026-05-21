/**
 * @description       :
 * @author            : laszlo.fodor@veeva.com
 * @group             :
 * @last modified on  : 05-21-2026
 * @last modified by  : daniel.magyar@veeva.com
 **/
@isTest
global class VI_VEEV_HippoEventCloneHelperTest {
    static Hippo_Event__c hippoEvent;
    
    private static Map<String, Id> countryIdMap;
    private static Map<String, Id> userSettingIdMap;
    private static Map<String, User> runAsUserMap;
    private static Id regionId;

    private static void initializeIds() {
        if (countryIdMap != null) return;
        
        countryIdMap = new Map<String, Id>();
        for (Hippo_Country__c c : [SELECT Id, Name FROM Hippo_Country__c WHERE Name IN ('Spain', 'France', 'United Kingdom')]) {
            countryIdMap.put(c.Name, c.Id);
        }
        
        List<Hippo_Region__c> regions = [SELECT Id FROM Hippo_Region__c LIMIT 1];
        if (!regions.isEmpty()) regionId = regions[0].Id;
        
        userSettingIdMap = new Map<String, Id>();
        runAsUserMap = new Map<String, User>();
        List<Hippo_User_Settings__c> allSettings = [SELECT Id, User__c, Country__r.Name FROM Hippo_User_Settings__c WHERE Enable__c = TRUE AND VIA_HIP_ParentHippoUserSetting__c = null];
        
        Set<Id> userIds = new Set<Id>();
        for (Hippo_User_Settings__c us : allSettings) {
            userIds.add(us.User__c);
        }
        Map<Id, User> usersMap = new Map<Id, User>([SELECT Id FROM User WHERE Id IN :userIds]);

        for (Hippo_User_Settings__c us : allSettings) {
            if (us.Country__r.Name != null && !userSettingIdMap.containsKey(us.Country__r.Name)) {
                userSettingIdMap.put(us.Country__r.Name, us.Id);
                runAsUserMap.put(us.Country__r.Name, usersMap.get(us.User__c));
            }
        }
        
        if (!allSettings.isEmpty()) {
            Id firstSettingId = allSettings[0].Id;
            User firstUser = usersMap.get(allSettings[0].User__c);
            for (String c : new List<String>{'Spain', 'France', 'United Kingdom'}) {
                if (!userSettingIdMap.containsKey(c)) {
                    userSettingIdMap.put(c, firstSettingId);
                    runAsUserMap.put(c, firstUser);
                }
            }
        }
    }


    @isTest(SeeAllData=true)
    static void testHippoEventCreateES() {
        initializeIds();
        System.runAs(runAsUserMap.get('Spain')) {
            Hippo_Event__c event = new Hippo_Event__c(
                Name = 'test1',
                Start_Event_Date__c = System.today(),
                End_Event_Date__c = System.today(),
                TrackingNumber__c = 'test tracking number',
                Status__c = 'Approved',
                Type__c = 'Roundtable',
                Requesting_Party_Name_Sync__c = 'test requesting party name',
                Requesting_Party_Title_Sync__c = 'test requesting party title',
                Requesting_Party_Location_Sync__c = 'test location',
                Requesting_Party_Department_Sync__c = 'test department',
                Country__c = countryIdMap.get('Spain'),
                VIA_HIP_Subtype__c = 'Commercial',
                Parent_User_Setting__c = userSettingIdMap.get('Spain'),
                Region__c = regionId
            );

            Test.startTest();

            insert event;

            Test.stopTest();

            List<Medical_Event_vod__c> events = [SELECT Id, VIA_Hippo_Event__c, VIA_Country_Code__c, VIA_Status__c, VIA_Event_Type__c, RecordType.DeveloperName FROM Medical_Event_vod__c WHERE VIA_Hippo_Event__c = :event.Id];

            System.debug(events);

            System.assertEquals(1, events.size());
        }
    }

    @IsTest(SeeAllData=true)
    static void testAttendeeCreateES() {
        initializeIds();
        System.runAs(runAsUserMap.get('Spain')) {
        // creating new hippo event - not approved
        Hippo_Event__c event = new Hippo_Event__c(
            Name = 'test_ES',
            Start_Event_Date__c = System.today(),
            End_Event_Date__c = System.today(),
            TrackingNumber__c = 'test tracking number x',
            Status__c = 'Approved',
            Type__c = 'Roundtable',
            Requesting_Party_Name_Sync__c = 'test requesting party name',
            Requesting_Party_Title_Sync__c = 'test requesting party title',
            Requesting_Party_Location_Sync__c = 'test location',
            Requesting_Party_Department_Sync__c = 'test department',
            Country__c = countryIdMap.get('Spain'),
            VIA_HIP_Subtype__c = 'Commercial',
            Parent_User_Setting__c = userSettingIdMap.get('Spain'),
            Region__c = regionId
        );

        Test.startTest();

        // insert event
        System.debug('Inserting Event: ' + event);
        insert event;
        System.debug('Event inserted with ID: ' + event.Id);

        ID hippoEventId = event.Id;

        // Create a new Hippo HCP related to the parent Hippo Event
        Event_HCP__c hippoEventAttendee = new Event_HCP__c(
            CreatedById = '0050W000006s7snQAA',
            LastModifiedById = '0050W000006s7snQAA',
            CurrencyIsoCode = 'EUR',
            Event__c = hippoEventId,
            HCP_Account__c = 'a6B3W000000etNFUAY' // get An Account Id here
        );
        System.debug('Inserting Event Attendee: ' + hippoEventAttendee);
        insert hippoEventAttendee;
        System.debug('Event Attendee inserted with ID: ' + hippoEventAttendee.Id);

        ID hippoEventAttendeeId = hippoEventAttendee.Id;
 
        List<Event_Attendee_vod__c> attendees = [SELECT Id, First_Name_vod__c, Last_Name_vod__c, EPD_FR_MED_Attendee_Specialty__c FROM Event_Attendee_vod__c WHERE VIA_Event_HCP__c = :hippoEventAttendeeId];

        System.debug('Attendees retrieved: ' + attendees);

        // check length of this result
        System.assertEquals(1, attendees.size());
        System.assertNotEquals(null, attendees[0].First_Name_vod__c, 'First Name is populated.');
        System.assertNotEquals(null, attendees[0].Last_Name_vod__c, 'Last Name is populated.');
            }
    }

    @IsTest(SeeAllData=true)
    static void testAttendeeCreateFR() {
        initializeIds();
        // creating new hippo event - not approved
        Hippo_Event__c event = new Hippo_Event__c(
            Name = 'test_FR',
            Start_Event_Date__c = System.today(),
            End_Event_Date__c = System.today(),
            TrackingNumber__c = 'test tracking number x',
            Status__c = 'Approved',
            Type__c = 'Roundtable',
            Requesting_Party_Name_Sync__c = 'test requesting party name',
            Requesting_Party_Title_Sync__c = 'test requesting party title',
            Requesting_Party_Location_Sync__c = 'test location',
            Requesting_Party_Department_Sync__c = 'test department',
            Country__c = countryIdMap.get('France'),
            VIA_HIP_Subtype__c = 'Commercial',
            Parent_User_Setting__c = userSettingIdMap.get('France'),
            Region__c = regionId
        );

        Test.startTest();

        // insert event
        insert event;

        ID hippoEventId = event.Id;

        // Create a new Hippo HCP related to the parent Hippo Event
        Event_HCP__c hippoEventAttendee = new Event_HCP__c(
            CreatedById = '0050W000006s7snQAA',
            LastModifiedById = '0050W000006s7snQAA',
            CurrencyIsoCode = 'EUR',
            Event__c = hippoEventId,
            HCP_Account__c = 'a6B3W000000etNFUAY' // get An Account Id here
        );

        insert hippoEventAttendee;

        ID hippoEventAttendeeId = hippoEventAttendee.Id;

        List<Event_Attendee_vod__c> attendees = [SELECT Id, First_Name_vod__c, Last_Name_vod__c, EPD_FR_MED_Attendee_Specialty__c FROM Event_Attendee_vod__c WHERE VIA_Event_HCP__c = :hippoEventAttendeeId];

        System.debug(attendees);

        // check length of this result
        System.assertEquals(1, attendees.size());
        System.assertNotEquals(null, attendees[0].First_Name_vod__c, 'First Name is populated.');
        System.assertNotEquals(null, attendees[0].Last_Name_vod__c, 'Last Name is populated.');
    }

    @isTest(SeeAllData=true)
    static void testHippoEventCreateFR() {
        initializeIds();
        Hippo_Event__c hippoevent = new Hippo_Event__c(
            Name = 'test FR1',
            Start_Event_Date__c = System.today(),
            End_Event_Date__c = System.today(),
            TrackingNumber__c = 'test tracking number',
            Status__c = 'Approved',
            Type__c = 'Roundtable',
            Requesting_Party_Name_Sync__c = 'test requesting party name',
            Requesting_Party_Title_Sync__c = 'test requesting party title',
            Requesting_Party_Location_Sync__c = 'test location',
            Requesting_Party_Department_Sync__c = 'test department',
            Channel__c = 'Live and Online',
            Event_subtype__c = 'Classic RP lunch / dinner with snack',
            Country__c = countryIdMap.get('France'),
            VIA_HIP_Subtype__c = 'Commercial',
            Parent_User_Setting__c = userSettingIdMap.get('France'),
            Region__c = regionId
        );

        Test.startTest();

        insert hippoevent;

        List<Medical_Event_vod__c> medevent = [
            SELECT Id, VIA_Hippo_Event__c, VIA_Country_Code__c, VIA_Status__c, VIA_Event_Type__c, EPD_FR_MED_Event_Status__c, EPD_FR_MED_Event_Subtype__c, VIA_Medical_Event_Category__c, VIA_Requesting_Party_Department__c, RecordType.DeveloperName, OwnerId
            FROM Medical_Event_vod__c
            WHERE VIA_Hippo_Event__c = :hippoevent.Id
        ];
        List<Event_Attendee_vod__c> attendee = [SELECT Id, User_vod__c, Expense_Attendee_Type_vod__c, Status_vod__c, Medical_Event_vod__c FROM Event_Attendee_vod__c WHERE Medical_Event_vod__r.VIA_Hippo_Event__c = :hippoevent.Id];

        System.debug('HippoEvent subtype: ' + hippoevent.Event_subtype__c);
        System.debug('HippoEvent country: ' + hippoevent.Country__c);
        for (Medical_Event_vod__c me : medevent) {
            System.debug('MedEvent subtype: ' + me.EPD_FR_MED_Event_Subtype__c);
            System.debug('MedEvent country: ' + me.VIA_Country_Code__c);
        }
        System.assertEquals(1, medevent.size());
        System.assertEquals('Hippo Approved', medevent[0].VIA_Status__c, 'Status = Hippo Approved');
        System.assertEquals('Hippo approved', medevent[0].EPD_FR_MED_Event_Status__c, 'Status = Hippo approved');
        System.assertEquals('Hybrid', medevent[0].VIA_Medical_Event_Category__c, 'Medical Event Category is Hybrid based on the Channel: Live and Online');
        System.assertEquals('Classic RP lunch / dinner with snack', medevent[0].EPD_FR_MED_Event_Subtype__c, 'Subtype = Classic RP lunch / dinner with snack');
        System.assertEquals('FR', medevent[0].VIA_Country_Code__c, 'France');
        System.assertEquals('test department', medevent[0].VIA_Requesting_Party_Department__c, 'The department should be inserted on the Medical Event.');
        System.assertEquals(medevent[0].OwnerId, attendee[0].User_vod__c, 'Owner Attendee set');
        System.assertEquals('SYSEMP', attendee[0].Expense_Attendee_Type_vod__c, 'SYSEMP set on Owner Attendee');
        System.assertEquals('Invited', attendee[0].Status_vod__c, 'Invité set on Owner Attendee');
    }

    @IsTest(SeeAllData=true)
    static void testHippoEventUpdateFR() {
        initializeIds();
        Hippo_Event__c hippoevent2 = new Hippo_Event__c(
            Name = 'test FR2',
            Start_Event_Date__c = System.today(),
            End_Event_Date__c = System.today(),
            TrackingNumber__c = 'test tracking number 2',
            Status__c = 'Draft',
            Type__c = 'Roundtable',
            Requesting_Party_Name_Sync__c = 'test requesting party name',
            Requesting_Party_Title_Sync__c = 'test requesting party title',
            Requesting_Party_Location_Sync__c = 'test location',
            Requesting_Party_Department_Sync__c = 'test department',
            Channel__c = 'Webinar',
            Event_subtype__c = 'Classic RP lunch / dinner with snack',
            Country__c = countryIdMap.get('France'),
            VIA_HIP_Subtype__c = 'Commercial',
            Parent_User_Setting__c = userSettingIdMap.get('France'),
            Region__c = regionId
        );
        insert hippoevent2;

        Test.startTest();

        Hippo_Event__c existingHippoEvent = [SELECT Id, Status__c FROM Hippo_Event__c WHERE Id = :hippoevent2.Id];
        existingHippoEvent.Status__c = 'Approved';
        boolean defaultValue = VS_EventTriggerHandler.isSkipTriggerForTest;

        try {
            VS_EventTriggerHandler.isSkipTriggerForTest = true;
            update existingHippoEvent;
        } finally {
            VS_EventTriggerHandler.isSkipTriggerForTest = defaultValue;
        }

        Test.stopTest();

        Hippo_Event__c updatedHippoEvent = [SELECT TrackingNumber__c, Status__c FROM Hippo_Event__c WHERE Id = :existingHippoEvent.Id];
        List<Medical_Event_vod__c> updatedmedevent = [
            SELECT VIA_Tracking_Number__c, EPD_FR_MED_Event_Status__c, VIA_Status__c, VIA_Medical_Event_Category__c, EPD_FR_MED_Event_Subtype__c, OwnerId
            FROM Medical_Event_vod__c
            WHERE VIA_Hippo_Event__c = :hippoevent2.Id
        ];
        List<Event_Attendee_vod__c> attendee = [SELECT Id, User_vod__c, Expense_Attendee_Type_vod__c, Status_vod__c, Medical_Event_vod__c FROM Event_Attendee_vod__c WHERE Medical_Event_vod__r.VIA_Hippo_Event__c = :hippoevent2.Id];

        System.assertEquals(1, updatedmedevent.size(), 'There should be one updated medical event');
        System.assertEquals('Remote', updatedmedevent[0].VIA_Medical_Event_Category__c, 'Medical Event Category is Remote');
        System.assertEquals('Classic RP lunch / dinner with snack', updatedmedevent[0].EPD_FR_MED_Event_Subtype__c, 'Subtype = Classic RP lunch / dinner with snack');
        System.assertEquals(updatedmedevent[0].OwnerId, attendee[0].User_vod__c, 'Owner Attendee set');
        System.assertEquals('SYSEMP', attendee[0].Expense_Attendee_Type_vod__c, 'SYSEMP set on Owner Attendee');
        System.assertEquals('Invited', attendee[0].Status_vod__c, 'Invité set on Owner Attendee');
    }

    @IsTest(SeeAllData=true)
    static void testAttendeeDeleteFR() {
        initializeIds();
        Hippo_Event__c event = new Hippo_Event__c(
            Name = 'test_FR3',
            Start_Event_Date__c = System.today(),
            End_Event_Date__c = System.today(),
            TrackingNumber__c = 'test tracking number 3',
            Status__c = 'Approved',
            Type__c = 'Roundtable',
            Requesting_Party_Name_Sync__c = 'test requesting party name',
            Requesting_Party_Title_Sync__c = 'test requesting party title',
            Requesting_Party_Location_Sync__c = 'test location',
            Requesting_Party_Department_Sync__c = 'test department',
            Country__c = countryIdMap.get('France'),
            VIA_HIP_Subtype__c = 'Commercial',
            Parent_User_Setting__c = userSettingIdMap.get('France'),
            Region__c = regionId
        );

        Test.startTest();

        insert event;

        ID hippoEventId = event.Id;

        Event_HCP__c hippoEventAttendee = new Event_HCP__c(
            CreatedById = '0050W000006s7snQAA',
            LastModifiedById = '0050W000006s7snQAA',
            CurrencyIsoCode = 'EUR',
            Event__c = hippoEventId,
            HCP_Account__c = 'a6B3W000000etNFUAY' // get An Account Id here
        );

        insert hippoEventAttendee;

        delete hippoEventAttendee;

        List<Medical_Event_vod__c> medEvent = [SELECT Id FROM Medical_Event_vod__c WHERE VIA_Hippo_Event__c = :hippoEventId];
        ID medEventId = medEvent[0].Id;
        List<Event_Attendee_vod__c> attendees = [SELECT Id, Status_vod__c FROM Event_Attendee_vod__c WHERE Medical_Event_vod__c = :medEventId];

        System.debug(attendees);

        System.assertEquals(2, attendees.size());
        System.assertEquals('Cancelled', attendees[1].Status_vod__c, 'Cancelled Event_Attendee_vod__c.Status_vod__c');
    }

    @IsTest(SeeAllData=true)
    static void testAttendeeDeleteES() {
        initializeIds();
        System.runAs(runAsUserMap.get('France')) {
        Hippo_Event__c event = new Hippo_Event__c(
            Name = 'test_FR3',
            Start_Event_Date__c = System.today(),
            End_Event_Date__c = System.today(),
            TrackingNumber__c = 'test tracking number 3',
            Status__c = 'Approved',
            Type__c = 'Roundtable',
            Requesting_Party_Name_Sync__c = 'test requesting party name',
            Requesting_Party_Title_Sync__c = 'test requesting party title',
            Requesting_Party_Location_Sync__c = 'test location',
            Requesting_Party_Department_Sync__c = 'test department',
            Country__c = countryIdMap.get('France'),
            VIA_HIP_Subtype__c = 'Commercial',
            Parent_User_Setting__c = userSettingIdMap.get('Spain'),
            Region__c = regionId
        );

        Test.startTest();

        insert event;

        ID hippoEventId = event.Id;

        Event_HCP__c hippoEventAttendee = new Event_HCP__c(CreatedById = '0050W000006s7snQAA', LastModifiedById = '0050W000006s7snQAA', CurrencyIsoCode = 'EUR', Event__c = hippoEventId, HCP_Account__c = 'a6B3W000000etNFUAY');

        insert hippoEventAttendee;

        delete hippoEventAttendee;

        ID hippoEventAttendeeId = hippoEventAttendee.Id;

        List<Event_Attendee_vod__c> attendees = [SELECT Id FROM Event_Attendee_vod__c WHERE VIA_Event_HCP__c = :hippoEventAttendeeId];

        System.debug(attendees);

        System.assertNotEquals(1, attendees.size(), 'Deleted Event_Attendee_vod__c');
            }
    }

    @IsTest(SeeAllData=true)
    static void testAttendeeCreateFromInteractionFR() {
        initializeIds();
        Hippo_Event__c event = new Hippo_Event__c(
            Name = 'test_FR',
            Start_Event_Date__c = System.today(),
            End_Event_Date__c = System.today(),
            TrackingNumber__c = 'test tracking number x',
            Status__c = 'Approved',
            Type__c = 'Roundtable',
            Requesting_Party_Name_Sync__c = 'test requesting party name',
            Requesting_Party_Title_Sync__c = 'test requesting party title',
            Requesting_Party_Location_Sync__c = 'test location',
            Requesting_Party_Department_Sync__c = 'test department',
            Country__c = countryIdMap.get('France'),
            VIA_HIP_Subtype__c = 'Commercial',
            Parent_User_Setting__c = userSettingIdMap.get('France'),
            Region__c = regionId
        );

        Test.startTest();

        insert event;

        ID hippoEventId = event.Id;

        Hippo_Interaction__c hippoEventAttendee = new Hippo_Interaction__c(CurrencyIsoCode = 'EUR', Hippo_Event__c = hippoEventId, HCP_Account__c = 'a6B3W000000etNFUAY', Status__c = 'Approved', Travel_Cost_Calculation__c = 1, Type__c = 'Engagement');

        boolean defaultValue = VS_InteractionTriggerHandler.isSkipTriggerForTest;
        try {
            VS_InteractionTriggerHandler.isSkipTriggerForTest = true;
            insert hippoEventAttendee;
        } finally {
            VS_InteractionTriggerHandler.isSkipTriggerForTest = defaultValue;
        }

        List<Event_Attendee_vod__c> attendees = [SELECT Id, First_Name_vod__c, Last_Name_vod__c, Status_vod__c, Incurred_Expense_vod__c FROM Event_Attendee_vod__c WHERE Medical_Event_vod__r.VIA_Hippo_Event__c = :hippoEventId];
        List<Medical_Event_vod__c> medEvent = [SELECT Id, MYL_FR_Paid_Speaker__c FROM Medical_Event_vod__c WHERE VIA_Hippo_Event__c = :hippoEventId];

        System.debug(attendees);

        System.assertEquals(2, attendees.size());
        System.assertEquals('Invited', attendees[1].Status_vod__c, 'Invited Event_Attendee_vod__c.Status_vod__c');
        System.assertEquals(true, attendees[1].Incurred_Expense_vod__c, 'Incurred Expense is checked');
        System.assertEquals('Yes', medEvent[0].MYL_FR_Paid_Speaker__c, 'Paid Speaker changed to Yes');
    }

    @IsTest(SeeAllData=true)
    static void testAttendeeUpsertFromInteractionFR() {
        initializeIds();
        // creating new hippo event - not approved
        Hippo_Event__c event = new Hippo_Event__c(
            Name = 'test_FR',
            Start_Event_Date__c = System.today(),
            End_Event_Date__c = System.today(),
            TrackingNumber__c = 'test tracking number x',
            Status__c = 'Approved',
            Type__c = 'Roundtable',
            Requesting_Party_Name_Sync__c = 'test requesting party name',
            Requesting_Party_Title_Sync__c = 'test requesting party title',
            Requesting_Party_Location_Sync__c = 'test location',
            Requesting_Party_Department_Sync__c = 'test department',
            Country__c = countryIdMap.get('France'),
            VIA_HIP_Subtype__c = 'Commercial',
            Parent_User_Setting__c = userSettingIdMap.get('France'),
            Region__c = regionId
        );

        Test.startTest();

        // insert event
        insert event;

        ID hippoEventId = event.Id;

        Hippo_Interaction__c hippoEventAttendee = new Hippo_Interaction__c(CurrencyIsoCode = 'EUR', Hippo_Event__c = hippoEventId, HCP_Account__c = 'a6B3W000000etNFUAY', Status__c = 'Draft');

        boolean defaultValue = VS_InteractionTriggerHandler.isSkipTriggerForTest;
        try {
            VS_InteractionTriggerHandler.isSkipTriggerForTest = true;
            insert hippoEventAttendee;
        } finally {
            VS_InteractionTriggerHandler.isSkipTriggerForTest = defaultValue;
        }

        Hippo_Interaction__c existingHippoEventAttendee = [SELECT Id, Status__c FROM Hippo_Interaction__c WHERE Id = :hippoEventAttendee.Id];
        existingHippoEventAttendee.Status__c = 'Approved';
        update existingHippoEventAttendee;

        List<Event_Attendee_vod__c> attendees = [SELECT Id, First_Name_vod__c, Last_Name_vod__c, Status_vod__c FROM Event_Attendee_vod__c WHERE Medical_Event_vod__r.VIA_Hippo_Event__c = :hippoEventId];

        System.debug(attendees);

        // check length of this result
        System.assertEquals(2, attendees.size());
        System.assertEquals('Invited', attendees[1].Status_vod__c, 'Invited Event_Attendee_vod__c.Status_vod__c');
    }

    @IsTest(SeeAllData=true)
    static void testAttendeeUpdateFromInteractionFR() {
        initializeIds();
        Hippo_Event__c event = new Hippo_Event__c(
            Name = 'test_FR',
            Start_Event_Date__c = System.today(),
            End_Event_Date__c = System.today(),
            TrackingNumber__c = 'test tracking number x',
            Status__c = 'Approved',
            Type__c = 'Roundtable',
            Requesting_Party_Name_Sync__c = 'test requesting party name',
            Requesting_Party_Title_Sync__c = 'test requesting party title',
            Requesting_Party_Location_Sync__c = 'test location',
            Requesting_Party_Department_Sync__c = 'test department',
            Country__c = countryIdMap.get('France'),
            VIA_HIP_Subtype__c = 'Commercial',
            Parent_User_Setting__c = userSettingIdMap.get('France'),
            Region__c = regionId
        );
        Test.startTest();

        // insert event
        insert event;

        ID hippoEventId = event.Id;

        Hippo_Interaction__c hippoEventAttendee = new Hippo_Interaction__c(CurrencyIsoCode = 'EUR', Hippo_Event__c = hippoEventId, HCP_Account__c = 'a6B3W000000etNFUAY', Status__c = 'Approved');

        boolean defaultValue = VS_InteractionTriggerHandler.isSkipTriggerForTest;
        try {
            VS_InteractionTriggerHandler.isSkipTriggerForTest = true;
            insert hippoEventAttendee;
        } finally {
            VS_InteractionTriggerHandler.isSkipTriggerForTest = defaultValue;
        }

        Hippo_Interaction__c existingHippoEventAttendee = [SELECT Id, Status__c FROM Hippo_Interaction__c WHERE Id = :hippoEventAttendee.Id];
        existingHippoEventAttendee.Status__c = 'Cancelled';
        update existingHippoEventAttendee;

        ID existingHippoEventAttendeeId = existingHippoEventAttendee.Id;

        List<Event_Attendee_vod__c> attendees = [SELECT Id, First_Name_vod__c, Last_Name_vod__c, Status_vod__c, VIA_Hippo_Interaction__c FROM Event_Attendee_vod__c WHERE Medical_Event_vod__r.VIA_Hippo_Event__c = :hippoEventId];

        System.debug(attendees);

        System.assertEquals(2, attendees.size());
        System.assertEquals('Cancelled', attendees[1].Status_vod__c, 'Cancelled Event_Attendee_vod__c.Status_vod__c.');
        System.assertEquals(existingHippoEventAttendeeId, attendees[1].VIA_Hippo_Interaction__c, 'VIA_Hippo_Interaction__c is stamped properly.');
    }

    @IsTest(SeeAllData=true)
    static void testAttendeeInsertFromInteractionDraftFR() {
        initializeIds();
        Hippo_Event__c event = new Hippo_Event__c(
            Name = 'test_FR',
            Start_Event_Date__c = System.today(),
            End_Event_Date__c = System.today(),
            TrackingNumber__c = 'test tracking number x',
            Status__c = 'Approved',
            Type__c = 'Roundtable',
            Requesting_Party_Name_Sync__c = 'test requesting party name',
            Requesting_Party_Title_Sync__c = 'test requesting party title',
            Requesting_Party_Location_Sync__c = 'test location',
            Requesting_Party_Department_Sync__c = 'test department',
            Country__c = countryIdMap.get('France'),
            VIA_HIP_Subtype__c = 'Commercial',
            Parent_User_Setting__c = userSettingIdMap.get('France'),
            Region__c = regionId
        );

        Test.startTest();

        insert event;

        ID hippoEventId = event.Id;

        Hippo_Interaction__c hippoEventAttendee = new Hippo_Interaction__c(CurrencyIsoCode = 'EUR', Hippo_Event__c = hippoEventId, HCP_Account__c = 'a6B3W000000etNFUAY', Status__c = 'Draft');

        boolean defaultValue = VS_InteractionTriggerHandler.isSkipTriggerForTest;
        try {
            VS_InteractionTriggerHandler.isSkipTriggerForTest = true;
            insert hippoEventAttendee;
        } finally {
            VS_InteractionTriggerHandler.isSkipTriggerForTest = defaultValue;
        }

        List<Event_Attendee_vod__c> attendees = [SELECT Id, First_Name_vod__c, Last_Name_vod__c, Status_vod__c FROM Event_Attendee_vod__c WHERE Medical_Event_vod__r.VIA_Hippo_Event__c = :hippoEventId];

        System.debug(attendees);

        System.assertEquals(1, attendees.size());
    }

    @IsTest(SeeAllData=true)
    static void testAttendeeUpdateFromInteractionFromDraftToApprovedFR() {
        initializeIds();
        Hippo_Event__c event = new Hippo_Event__c(
            Name = 'test_FR',
            Start_Event_Date__c = System.today(),
            End_Event_Date__c = System.today(),
            TrackingNumber__c = 'test tracking number x',
            Status__c = 'Approved',
            Type__c = 'Roundtable',
            Requesting_Party_Name_Sync__c = 'test requesting party name',
            Requesting_Party_Title_Sync__c = 'test requesting party title',
            Requesting_Party_Location_Sync__c = 'test location',
            Requesting_Party_Department_Sync__c = 'test department',
            Country__c = countryIdMap.get('France'),
            VIA_HIP_Subtype__c = 'Commercial',
            Parent_User_Setting__c = userSettingIdMap.get('France'),
            Region__c = regionId
        );
        Test.startTest();

        insert event;

        ID hippoEventId = event.Id;

        Hippo_Interaction__c hippoEventAttendee = new Hippo_Interaction__c(CreatedById = '0050W000006s7snQAA', LastModifiedById = '0050W000006s7snQAA', CurrencyIsoCode = 'EUR', Hippo_Event__c = hippoEventId, HCP_Account__c = 'a6B3W000000etNFUAY', Status__c = 'Draft');

        boolean defaultValue = VS_InteractionTriggerHandler.isSkipTriggerForTest;
        try {
            VS_InteractionTriggerHandler.isSkipTriggerForTest = true;
            insert hippoEventAttendee;
        } finally {
            VS_InteractionTriggerHandler.isSkipTriggerForTest = defaultValue;
        }

        Hippo_Interaction__c existingHippoEventAttendee = [SELECT Id, Status__c FROM Hippo_Interaction__c WHERE Id = :hippoEventAttendee.Id];
        existingHippoEventAttendee.Status__c = 'Approved';
        update existingHippoEventAttendee;

        List<Event_Attendee_vod__c> attendees = [SELECT Id, First_Name_vod__c, Last_Name_vod__c, Status_vod__c FROM Event_Attendee_vod__c WHERE Medical_Event_vod__r.VIA_Hippo_Event__c = :hippoEventId];

        System.debug(attendees);

        System.assertEquals(2, attendees.size());
        System.assertEquals('Invited', attendees[1].Status_vod__c, 'Approved Event_Attendee_vod__c.Status_vod__c');
    }

    @IsTest(SeeAllData=true)
    static void testAttendeeUpdateFromEventHCPandInteractionFR() {
        initializeIds();
        Hippo_Event__c event = new Hippo_Event__c(
            Name = 'test_FR',
            Start_Event_Date__c = System.today(),
            End_Event_Date__c = System.today(),
            TrackingNumber__c = 'test tracking number x',
            Status__c = 'Approved',
            Type__c = 'Roundtable',
            Requesting_Party_Name_Sync__c = 'test requesting party name',
            Requesting_Party_Title_Sync__c = 'test requesting party title',
            Requesting_Party_Location_Sync__c = 'test location',
            Requesting_Party_Department_Sync__c = 'test department',
            Country__c = countryIdMap.get('France'),
            VIA_HIP_Subtype__c = 'Commercial',
            Parent_User_Setting__c = userSettingIdMap.get('France'),
            Region__c = regionId
        );
        Test.startTest();

        // insert event
        insert event;

        ID hippoEventId = event.Id;

        Hippo_Interaction__c hippoEventAttendeeFromInteraction = new Hippo_Interaction__c(CreatedById = '0050W000006s7snQAA', LastModifiedById = '0050W000006s7snQAA', CurrencyIsoCode = 'EUR', Hippo_Event__c = hippoEventId, HCP_Account__c = 'a6B3W000000etNFUAY', Status__c = 'Approved');

        boolean defaultValue = VS_InteractionTriggerHandler.isSkipTriggerForTest;
        try {
            VS_InteractionTriggerHandler.isSkipTriggerForTest = true;
            insert hippoEventAttendeeFromInteraction;
        } finally {
            VS_InteractionTriggerHandler.isSkipTriggerForTest = defaultValue;
        }

        Event_HCP__c hippoEventAttendeeFromEventHCP = new Event_HCP__c(CurrencyIsoCode = 'EUR', Event__c = hippoEventId, HCP_Account__c = 'a6B3W000000etNFUAY');

        insert hippoEventAttendeeFromEventHCP;

        List<Event_Attendee_vod__c> attendees = [SELECT Id, First_Name_vod__c, Last_Name_vod__c, Status_vod__c FROM Event_Attendee_vod__c WHERE Medical_Event_vod__r.VIA_Hippo_Event__c = :hippoEventId];

        System.debug(attendees);

        System.assertEquals(2, attendees.size(), 'No duplicate attendees.');
    }

    @isTest(SeeAllData=true)
    static void testEventTypePopulationOnEventFR() {
        initializeIds();
        User testUser = [SELECT Id, Division, Title, Name FROM User WHERE Username = 'elisabeth.silva@viatris.com.fullemea' LIMIT 1];

        System.runAs(testUser) {
            Hippo_Event__c hippoevent = new Hippo_Event__c(
                Name = 'test FR1',
                Start_Event_Date__c = System.today(),
                End_Event_Date__c = System.today(),
                TrackingNumber__c = 'test tracking number',
                Status__c = 'Approved',
                Type__c = 'Roundtable',
                Requesting_Party_Name_Sync__c = 'test requesting party name',
                Requesting_Party_Title_Sync__c = 'test requesting party title',
                Requesting_Party_Location_Sync__c = 'test location',
                Requesting_Party_Department_Sync__c = 'test department',
                Channel__c = 'Live and Online',
                Event_subtype__c = 'Classic RP lunch / dinner with snack',
                Country__c = countryIdMap.get('France'),
                VIA_HIP_Subtype__c = 'Commercial',
                Parent_User_Setting__c = userSettingIdMap.get('France'),
                Region__c = regionId
            );

            Test.startTest();

            insert hippoevent;

            Test.stopTest();

            List<Medical_Event_vod__c> medevent = [
                SELECT Id, Event_type__c, VIA_Hippo_Event__c, VIA_Country_Code__c, VIA_Status__c, VIA_Event_Type__c, EPD_FR_MED_Event_Status__c, EPD_FR_MED_Event_Subtype__c, VIA_Medical_Event_Category__c, VIA_Requesting_Party_Department__c, RecordType.DeveloperName, OwnerId, CreatedBy.Name
                FROM Medical_Event_vod__c
                WHERE VIA_Hippo_Event__c = :hippoevent.Id
            ];
            List<Event_Attendee_vod__c> attendee = [SELECT Id, User_vod__c, Expense_Attendee_Type_vod__c, Status_vod__c, Medical_Event_vod__c FROM Event_Attendee_vod__c WHERE Medical_Event_vod__r.VIA_Hippo_Event__c = :hippoevent.Id];

            System.debug('HippoEvent subtype: ' + hippoevent.Event_subtype__c);
            System.debug('HippoEvent country: ' + hippoevent.Country__c);
            for (Medical_Event_vod__c me : medevent) {
                System.debug('MedEvent subtype: ' + me.EPD_FR_MED_Event_Subtype__c);
                System.debug('MedEvent country: ' + me.VIA_Country_Code__c);
                System.debug('MedEvent Event Type: ' + me.Event_type__c);
            }
            System.assertEquals(1, medevent.size());
            System.assertEquals('Hippo Approved', medevent[0].VIA_Status__c, 'Status = Hippo approved');
            System.assertEquals('Roundtable', medevent[0].Event_type__c, 'Event type = Roundtable (Direct)');
            System.assertEquals('Hybrid', medevent[0].VIA_Medical_Event_Category__c, 'Medical Event Category is Hybrid based on the Channel: Live and Online');
            System.assertEquals('Classic RP lunch / dinner with snack', medevent[0].EPD_FR_MED_Event_Subtype__c, 'Subtype = Classic RP lunch / dinner with snack');
            System.assertEquals('FR', medevent[0].VIA_Country_Code__c, 'France');
            System.assertEquals('test department', medevent[0].VIA_Requesting_Party_Department__c, 'The department should be inserted on the Medical Event.');
            System.assertEquals(medevent[0].OwnerId, attendee[0].User_vod__c, 'Owner Attendee set');
            System.assertEquals('SYSEMP', attendee[0].Expense_Attendee_Type_vod__c, 'SYSok set on Owner Attendee');
            System.assertEquals('Invited', attendee[0].Status_vod__c, 'Invité set on Owner Attendee');
        }
    }

    @isTest(SeeAllData=true)
    static void testHippoEventCreateESMedicalAffairs() {
        initializeIds();
        System.runAs(runAsUserMap.get('Spain')) {
        Hippo_Event__c event = new Hippo_Event__c(
            Name = 'test1',
            Start_Event_Date__c = System.today(),
            End_Event_Date__c = System.today(),
            TrackingNumber__c = 'test tracking number',
            Status__c = 'Approved',
            Type__c = 'Roundtable',
            Requesting_Party_Name_Sync__c = 'test requesting party name',
            Requesting_Party_Title_Sync__c = 'test requesting party title',
            Requesting_Party_Location_Sync__c = 'test location',
            Requesting_Party_Department_Sync__c = 'test department',
            Country__c = countryIdMap.get('Spain'),
            VIA_HIP_Subtype__c = 'Medical',
            Parent_User_Setting__c = userSettingIdMap.get('Spain'),
            Region__C = regionId
        );

        Test.startTest();

        insert event;

        Test.stopTest();

        List<Medical_Event_vod__c> events = [SELECT Id, VIA_Hippo_Event__c, VIA_Country_Code__c, VIA_Status__c, VIA_Event_Type__c, RecordType.DeveloperName FROM Medical_Event_vod__c WHERE VIA_Hippo_Event__c = :event.Id];

        System.debug(events);

        System.assertEquals(0, events.size());
            }
    }
    @IsTest(SeeAllData=true)
    static void testHippoEventUpdateUK() {
        initializeIds();
        User runAsUK = runAsUserMap.get('United Kingdom');

        Hippo_Event__c hippoevent2 = new Hippo_Event__c(
            Name = 'test UK',
            Start_Event_Date__c = System.today(),
            End_Event_Date__c = System.today(),
            TrackingNumber__c = 'test tracking number 2',
            Status__c = 'Draft',
            Type__c = 'Roundtable',
            Requesting_Party_Name_Sync__c = 'test requesting party name',
            Requesting_Party_Title_Sync__c = 'test requesting party title',
            Requesting_Party_Location_Sync__c = 'test location',
            Requesting_Party_Department_Sync__c = 'test department',
            Channel__c = 'Live and Online',
            Event_subtype__c = 'Classic RP lunch / dinner with snack',
            Country__c = countryIdMap.get('United Kingdom'),
            VIA_HIP_Subtype__c = 'Commercial',
            Parent_User_Setting__c = userSettingIdMap.get('United Kingdom'),
            Region__c = regionId,
            Event_venue__c = 'Coffee Beans UK',
            Address__c = '102 Derham Rd',
            City__c = 'Norwich',
            zipcode__c = '12200'
        );
        insert hippoevent2;

        Test.startTest();

        Hippo_Event__c existingHippoEvent = [SELECT Id, Status__c FROM Hippo_Event__c WHERE Id = :hippoevent2.Id];

        System.runAs(runAsUK) {
            existingHippoEvent.Status__c = 'Approved';
            boolean defaultValue = VS_EventTriggerHandler.isSkipTriggerForTest;

            try {
                VS_EventTriggerHandler.isSkipTriggerForTest = true;
                update existingHippoEvent;
            } finally {
                VS_EventTriggerHandler.isSkipTriggerForTest = defaultValue;
            }

            Hippo_Event__c updatedHippoEvent = [SELECT Id, LastModifiedBy.Name FROM Hippo_Event__c WHERE Id = :hippoevent2.Id];
            System.debug('LastModifiedBy.Name ===> ' + updatedHippoEvent.LastModifiedBy.Name);
        }
        Test.stopTest();

        Hippo_Event__c updatedHippoEvent = [SELECT TrackingNumber__c, Status__c, Status_Formula__c FROM Hippo_Event__c WHERE Id = :existingHippoEvent.Id];
        List<Medical_Event_vod__c> updatedmedevent = [
            SELECT VIA_Tracking_Number__c, EPD_FR_MED_Event_Status__c, VIA_Status__c, VIA_Medical_Event_Category__c, EPD_FR_MED_Event_Subtype__c, OwnerId, Location__c, VIA_Event_Type__c
            FROM Medical_Event_vod__c
            WHERE VIA_Hippo_Event__c = :hippoevent2.Id
        ];
        List<Event_Attendee_vod__c> attendee = [SELECT Id, User_vod__c, Expense_Attendee_Type_vod__c, Status_vod__c, Medical_Event_vod__c FROM Event_Attendee_vod__c WHERE Medical_Event_vod__r.VIA_Hippo_Event__c = :hippoevent2.Id];

        System.assertEquals(1, updatedmedevent.size(), 'There should be one updated medical event');
        System.assertEquals('Approved', updatedmedevent[0].VIA_Status__c, 'Approved');
        System.assertEquals('Roundtable', updatedmedevent[0].VIA_Event_Type__c, 'Roundtable');
        System.assertEquals('Coffee Beans UK, 102 Derham Rd, Norwich, 12200, United Kingdom', updatedmedevent[0].Location__c, 'Location is populated');
        System.assertEquals(updatedmedevent[0].OwnerId, attendee[0].User_vod__c, 'Owner Attendee set');
        System.assertEquals('SYSEMP', attendee[0].Expense_Attendee_Type_vod__c, 'SYSEMP set on Owner Attendee');
        System.assertEquals('Invited', attendee[0].Status_vod__c, 'Invité set on Owner Attendee');
    }

    @IsTest(SeeAllData=true)
    static void testHippoEventUpdateAndTerminateUK() {
        initializeIds();
        User runAsUK = runAsUserMap.get('United Kingdom');

        // Create a new Hippo Event for UK
        Hippo_Event__c hippoevent2 = new Hippo_Event__c(
            Name = 'test UK',
            Start_Event_Date__c = System.today(),
            End_Event_Date__c = System.today(),
            TrackingNumber__c = 'test tracking number 2',
            Status__c = 'Draft',
            Type__c = 'Roundtable',
            Requesting_Party_Name_Sync__c = 'test requesting party name',
            Requesting_Party_Title_Sync__c = 'test requesting party title',
            Requesting_Party_Location_Sync__c = 'test location',
            Requesting_Party_Department_Sync__c = 'test department',
            Channel__c = 'Live and Online',
            Event_subtype__c = 'Classic RP lunch / dinner with snack',
            Country__c = countryIdMap.get('United Kingdom'), // Assuming this is UK Country ID
            VIA_HIP_Subtype__c = 'Commercial',
            Parent_User_Setting__c = userSettingIdMap.get('United Kingdom'),
            Region__c = regionId,
            Event_venue__c = 'Coffee Beans UK',
            Address__c = '102 Derham Rd',
            City__c = 'Norwich',
            zipcode__c = '12200'
        );
        insert hippoevent2;

        Test.startTest();

        // Approve the Hippo Event first
        Hippo_Event__c existingHippoEvent = [SELECT Id, Status__c FROM Hippo_Event__c WHERE Id = :hippoevent2.Id];

        System.runAs(runAsUK) {
            existingHippoEvent.Status__c = 'Approved';
            boolean defaultValue = VS_EventTriggerHandler.isSkipTriggerForTest;

            try {
                VS_EventTriggerHandler.isSkipTriggerForTest = true;
                update existingHippoEvent;
            } finally {
                VS_EventTriggerHandler.isSkipTriggerForTest = defaultValue;
            }

            Hippo_Event__c updatedHippoEvent = [SELECT Id, LastModifiedBy.Name FROM Hippo_Event__c WHERE Id = :hippoevent2.Id];
            System.debug('LastModifiedBy.Name after approval ===> ' + updatedHippoEvent.LastModifiedBy.Name);
        }

        // Terminate the Hippo Event
        Hippo_Event__c hippoEventToTerminate = [SELECT Id, Status__c FROM Hippo_Event__c WHERE Id = :existingHippoEvent.Id];
        hippoEventToTerminate.Status__c = 'Terminated';

        System.runAs(runAsUK) {
            boolean defaultValue = VS_EventTriggerHandler.isSkipTriggerForTest;

            try {
                VS_EventTriggerHandler.isSkipTriggerForTest = true;
                update hippoEventToTerminate;
            } finally {
                VS_EventTriggerHandler.isSkipTriggerForTest = defaultValue;
            }
        }

        Test.stopTest();

        // Query the updated Medical Event related to the Hippo Event
        Hippo_Event__c updatedHippoEvent = [SELECT TrackingNumber__c, Status__c, Status_Formula__c FROM Hippo_Event__c WHERE Id = :existingHippoEvent.Id];
        List<Medical_Event_vod__c> updatedmedevent = [
            SELECT VIA_Tracking_Number__c, EPD_FR_MED_Event_Status__c, VIA_Status__c, VIA_Medical_Event_Category__c, EPD_FR_MED_Event_Subtype__c, OwnerId, Location__c, VIA_Event_Type__c, RecordType.DeveloperName
            FROM Medical_Event_vod__c
            WHERE VIA_Hippo_Event__c = :hippoevent2.Id
        ];

        // Check if the Medical Event is Terminated
        System.assertEquals(1, updatedmedevent.size(), 'There should be one updated medical event');
        System.assertEquals('Terminated', updatedmedevent[0].VIA_Status__c, 'The Medical Event should be marked as Terminated');
        System.assertEquals('VIA_UK_Completed_Medical_Event', updatedmedevent[0].RecordType.DeveloperName, 'The Medical Event Record Type should change to VIA_UK_Completed_Medical_Event');
        System.assertEquals('Coffee Beans UK, 102 Derham Rd, Norwich, 12200, United Kingdom', updatedmedevent[0].Location__c, 'Location is populated');

        // Attendee assertions
        List<Event_Attendee_vod__c> attendee = [SELECT Id, User_vod__c, Expense_Attendee_Type_vod__c, Status_vod__c, Medical_Event_vod__c FROM Event_Attendee_vod__c WHERE Medical_Event_vod__r.VIA_Hippo_Event__c = :hippoevent2.Id];
        System.assertEquals(updatedmedevent[0].OwnerId, attendee[0].User_vod__c, 'Owner Attendee set');
        System.assertEquals('SYSEMP', attendee[0].Expense_Attendee_Type_vod__c, 'SYSEMP set on Owner Attendee');
        System.assertEquals('Invited', attendee[0].Status_vod__c, 'Invited set on Owner Attendee');
    }

    @IsTest(SeeAllData=true)
    static void testHippoEventUpdateUKwithExpenses() {
        initializeIds();
        // Fetch a test user
        User runAsUK = runAsUserMap.get('United Kingdom');

        // Create a Hippo_Event__c record for the UK
        Hippo_Event__c hippoevent2 = new Hippo_Event__c(
            Name = 'test UK',
            Start_Event_Date__c = System.today(),
            End_Event_Date__c = System.today(),
            TrackingNumber__c = 'test tracking number 2',
            Status__c = 'Draft',
            Type__c = 'Roundtable',
            Requesting_Party_Name_Sync__c = 'test requesting party name',
            Requesting_Party_Title_Sync__c = 'test requesting party title',
            Requesting_Party_Location_Sync__c = 'test location',
            Requesting_Party_Department_Sync__c = 'test department',
            Channel__c = 'Live and Online',
            Event_subtype__c = 'Classic RP lunch / dinner with snack',
            Country__c = countryIdMap.get('United Kingdom'),
            VIA_HIP_Subtype__c = 'Commercial',
            Parent_User_Setting__c = userSettingIdMap.get('United Kingdom'),
            Region__c = regionId,
            Event_venue__c = 'Coffee Beans UK',
            Address__c = '102 Derham Rd',
            City__c = 'Norwich',
            zipcode__c = '12200'
        );
        insert hippoevent2;

        // Create associated Hippo_Event_Amount__c records
        List<Hippo_Event_Amount__c> eventAmounts = new List<Hippo_Event_Amount__c>();
        eventAmounts.add(new Hippo_Event_Amount__c(Event__c = hippoevent2.Id, Cost__c = 500.00, Currency__c = 'GBP', Label__c = 'Accommodation'));
        eventAmounts.add(new Hippo_Event_Amount__c(Event__c = hippoevent2.Id, Cost__c = 300.00, Currency__c = 'GBP', Label__c = 'Taxi'));
        boolean defaultValue = VS_EventTriggerHandler.isSkipTriggerForTest;

        try {
            VS_EventTriggerHandler.isSkipTriggerForTest = true;
            insert eventAmounts;
        } finally {
            VS_EventTriggerHandler.isSkipTriggerForTest = defaultValue;
        }

        Test.startTest();

        Hippo_Event__c existingHippoEvent = [SELECT Id, Status__c FROM Hippo_Event__c WHERE Id = :hippoevent2.Id];

        System.runAs(runAsUK) {
            existingHippoEvent.Status__c = 'Approved';

            try {
                VS_EventTriggerHandler.isSkipTriggerForTest = true;
                update existingHippoEvent;
            } finally {
                VS_EventTriggerHandler.isSkipTriggerForTest = defaultValue;
            }

            Hippo_Event__c updatedHippoEvent = [SELECT Id, LastModifiedBy.Name FROM Hippo_Event__c WHERE Id = :hippoevent2.Id];
            System.debug('LastModifiedBy.Name ===> ' + updatedHippoEvent.LastModifiedBy.Name);
        }
        Test.stopTest();

        // Query updated Hippo_Event__c
        Hippo_Event__c updatedHippoEvent = [SELECT TrackingNumber__c, Status__c, Status_Formula__c FROM Hippo_Event__c WHERE Id = :existingHippoEvent.Id];

        // Query associated Medical_Event_vod__c
        List<Medical_Event_vod__c> updatedMedEvents = [
            SELECT Id, VIA_Tracking_Number__c, EPD_FR_MED_Event_Status__c, VIA_Status__c, VIA_Medical_Event_Category__c, EPD_FR_MED_Event_Subtype__c, OwnerId, Location__c, VIA_Event_Type__c
            FROM Medical_Event_vod__c
            WHERE VIA_Hippo_Event__c = :hippoevent2.Id
        ];

        // Query Event_Attendee_vod__c
        List<Event_Attendee_vod__c> attendees = [
            SELECT Id, User_vod__c, Expense_Attendee_Type_vod__c, Status_vod__c, Medical_Event_vod__c
            FROM Event_Attendee_vod__c
            WHERE Medical_Event_vod__r.VIA_Hippo_Event__c = :hippoevent2.Id
        ];

        // Query created EPD_Event_Expense__c records
        List<EPD_Event_Expense__c> expenses = [
            SELECT Id, EPD_Medical_Event__c, EPD_Type__c, EPD_Planned_Cost__c, CurrencyIsoCode
            FROM EPD_Event_Expense__c
            WHERE EPD_Medical_Event__c = :updatedMedEvents[0].Id
        ];

        System.debug('Number of EPD_Event_Expense__c records retrieved: ' + expenses.size());
        for (EPD_Event_Expense__c expense : expenses) {
            System.debug('Expense Record: ' + expense);
            System.debug('Expense Id: ' + expense.Id);
            System.debug('Expense EPD_Medical_Event__c: ' + expense.EPD_Medical_Event__c);
            System.debug('Expense EPD_Type__c: ' + expense.EPD_Type__c);
            System.debug('Expense EPD_Planned_Cost__c: ' + expense.EPD_Planned_Cost__c);
            System.debug('Expense CurrencyIsoCode: ' + expense.CurrencyIsoCode);
        }

        // Assertions for Medical Event
        System.assertEquals(1, updatedMedEvents.size(), 'There should be one updated medical event');
        System.assertEquals('Approved', updatedMedEvents[0].VIA_Status__c, 'VIA_Status__c should be Approved');
        System.assertEquals('Roundtable', updatedMedEvents[0].VIA_Event_Type__c, 'VIA_Event_Type__c should be Roundtable');
        System.assertEquals('Coffee Beans UK, 102 Derham Rd, Norwich, 12200, United Kingdom', updatedMedEvents[0].Location__c, 'Location is populated correctly');

        // Assertions for Event Attendee
        System.assertEquals(updatedMedEvents[0].OwnerId, attendees[0].User_vod__c, 'Owner Attendee set correctly');
        System.assertEquals('SYSEMP', attendees[0].Expense_Attendee_Type_vod__c, 'Expense_Attendee_Type_vod__c is SYSEMP');
        System.assertEquals('Invited', attendees[0].Status_vod__c, 'Status_vod__c is Invited');

        // Assertions for EPD Event Expenses
        System.assertEquals(2, expenses.size(), 'There should be two EPD_Event_Expense__c records created');
        // Check that expenses have the correct data
        for (EPD_Event_Expense__c expense : expenses) {
            System.assertEquals(updatedMedEvents[0].Id, expense.EPD_Medical_Event__c, 'Expense is linked to the correct Medical Event');

            if (expense.EPD_Type__c == 'Stay Expenses') {
                System.assertEquals(500.00, expense.EPD_Planned_Cost__c, 'Stay Expenses is correct');
                System.assertEquals('GBP', expense.CurrencyIsoCode, 'Currency is GBP');
            }

            if (expense.EPD_Type__c == 'Taxi') {
                System.assertEquals(300.00, expense.EPD_Planned_Cost__c, 'Taxi is correct');
                System.assertEquals('GBP', expense.CurrencyIsoCode, 'Currency is GBP');
            }
        }
    }

    @IsTest(SeeAllData=true)
    static void testHippoEventUpdateUKwithInteractionExpensesWithoutEventHCP() {
        initializeIds();
        System.runAs(runAsUserMap.get('United Kingdom')) {
        // Get a test user (adjust the query as needed)
        User runAsUK = runAsUserMap.get('United Kingdom');

        // Create a UK Hippo_Event__c record.
        System.runAs(runAsUK) {
            Hippo_Event__c ukEvent = new Hippo_Event__c(
                Name = 'Test UK Without HCP',
                Start_Event_Date__c = Date.today(),
                End_Event_Date__c = Date.today(),
                TrackingNumber__c = 'Tracking-UK-001',
                Status__c = 'Draft',
                Type__c = 'Roundtable',
                Requesting_Party_Name_Sync__c = 'Test Party',
                Requesting_Party_Title_Sync__c = 'Test Title',
                Requesting_Party_Location_Sync__c = 'Test Location',
                Requesting_Party_Department_Sync__c = 'Test Dept',
                Channel__c = 'Webinar',
                Event_subtype__c = 'Classic RP lunch / dinner with snack',
                Country__c = countryIdMap.get('United Kingdom'),
                VIA_HIP_Subtype__c = 'Commercial',
                Parent_User_Setting__c = userSettingIdMap.get('United Kingdom'),
                Region__c = regionId,
                Event_venue__c = 'Coffee Beans UK',
                Address__c = '102 Derham Rd',
                City__c = 'Norwich',
                zipcode__c = '12200'
            );
            insert ukEvent;

            // Approve the event.
            Boolean origSkip = VS_InteractionTriggerHandler.isSkipTriggerForTest;
            VS_InteractionTriggerHandler.isSkipTriggerForTest = true;
            ukEvent.Status__c = 'Approved';
            update ukEvent;
            VS_InteractionTriggerHandler.isSkipTriggerForTest = origSkip;

            // Create a Hippo_Interaction__c record with no HCP_Account__c so no Event_HCP is created.
            Hippo_Interaction__c interaction = new Hippo_Interaction__c(CurrencyIsoCode = 'EUR', Hippo_Event__c = ukEvent.Id, HCP_Account__c = null, Status__c = 'Draft', Travel_Cost_Calculation__c = 1, Type__c = 'Engagement');
            VS_InteractionTriggerHandler.isSkipTriggerForTest = true;
            insert interaction;
            VS_InteractionTriggerHandler.isSkipTriggerForTest = origSkip;

            // Create associated Hippo_Interaction_Amount__c records.
            Hippo_Interaction_Amount__c amt1 = new Hippo_Interaction_Amount__c(Interaction__c = interaction.Id, Cost__c = 500.00, Currency__c = 'GBP', Label__c = 'Accommodation');
            Hippo_Interaction_Amount__c amt2 = new Hippo_Interaction_Amount__c(Interaction__c = interaction.Id, Cost__c = 300.00, Currency__c = 'GBP', Label__c = 'Taxi');
            VS_InteractionTriggerHandler.isSkipTriggerForTest = true;
            insert new List<Hippo_Interaction_Amount__c>{ amt1, amt2 };
            VS_InteractionTriggerHandler.isSkipTriggerForTest = origSkip;

            // Now update the interaction's status to Approved AFTER amounts are inserted.
            interaction.Status__c = 'Approved';
            VS_InteractionTriggerHandler.isSkipTriggerForTest = true;
            update interaction;
            VS_InteractionTriggerHandler.isSkipTriggerForTest = origSkip;

            // Query for the Medical_Event_vod__c record created for this Hippo event.
            List<Medical_Event_vod__c> medEvents = [SELECT Id FROM Medical_Event_vod__c WHERE VIA_Hippo_Event__c = :ukEvent.Id];
            System.assertNotEquals(0, medEvents.size(), 'A Medical Event record should exist for the UK Hippo Event.');
            Id medEventId = medEvents[0].Id;

            // Query for the expense records created from the interaction.
            List<EPD_Event_Expense__c> expenses = [
                SELECT Id, EPD_Medical_Event__c, EPD_Type__c, EPD_Planned_Cost__c, CurrencyIsoCode
                FROM EPD_Event_Expense__c
                WHERE EPD_Medical_Event__c = :medEventId
            ];

            System.assertEquals(2, expenses.size(), 'One expense record should be created from the interaction even without an Event_HCP.');

            EPD_Event_Expense__c exp = expenses[0];
            System.assertEquals('Stay Expenses', exp.EPD_Type__c, 'Expense type should be mapped correctly for Accommodation.');
            System.assertEquals(500.00, exp.EPD_Planned_Cost__c, 'Expense planned cost should match the interaction amount.');
            System.assertEquals('GBP', exp.CurrencyIsoCode, 'Expense currency should be GBP.');
        }
            }
    }

    @IsTest(SeeAllData=true)
    static void testHippoEventTerminateUKWithoutMedEvent() {
        initializeIds();
        System.runAs(runAsUserMap.get('United Kingdom')) {
        // UK draft Hippo Event (no Medical Event yet)
        Hippo_Event__c hippoEvent = new Hippo_Event__c(
            Name = 'UK Terminate – no MedEvent',
            Start_Event_Date__c = Date.today(),
            End_Event_Date__c = Date.today(),
            TrackingNumber__c = 'track‑term‑001',
            Status__c = 'Draft',
            Type__c = 'Roundtable',
            Requesting_Party_Name_Sync__c = 'Requester',
            Requesting_Party_Title_Sync__c = 'Title',
            Requesting_Party_Location_Sync__c = 'Location',
            Requesting_Party_Department_Sync__c = 'Dept',
            Channel__c = 'Webinar',
            Event_subtype__c = 'Classic RP lunch / dinner with snack',
            Country__c = countryIdMap.get('United Kingdom'), // UK country id
            VIA_HIP_Subtype__c = 'Commercial',
            Parent_User_Setting__c = userSettingIdMap.get('United Kingdom'),
            Region__c = regionId
        );
        insert hippoEvent;

        User runAsUK = runAsUserMap.get('United Kingdom');

        Test.startTest();
        System.runAs(runAsUK) {
            Hippo_Event__c toTerminate = [SELECT Id, Status__c FROM Hippo_Event__c WHERE Id = :hippoEvent.Id];
            toTerminate.Status__c = 'Terminated';

            Boolean def = VS_EventTriggerHandler.isSkipTriggerForTest;
            try {
                VS_EventTriggerHandler.isSkipTriggerForTest = true;
                update toTerminate;
            } finally {
                VS_EventTriggerHandler.isSkipTriggerForTest = def;
            }
        }
        Test.stopTest();

        // No Medical Event should have been created, and no exception thrown
        List<Medical_Event_vod__c> medEvents = [SELECT Id FROM Medical_Event_vod__c WHERE VIA_Hippo_Event__c = :hippoEvent.Id];
        System.assertEquals(0, medEvents.size(), 'Terminating a UK Hippo Event with no existing Medical Event must not create one.');
            }
    }

    @isTest(SeeAllData=true)
    static void testHippoEventCreateFR_AllTypesAndSubtypes() {
        initializeIds();
        System.runAs(runAsUserMap.get('France')) {
        Map<String, String> typeToExpectedTypeMap = new Map<String, String>{
            'Commercial Advisory Board' => 'Commercial Advisory Board',
            'Conference' => 'Conference',
            'Congress' => 'Congress',
            'Master Class' => 'Masterclass',
            'Roundtable' => 'Roundtable',
            'Site Visit' => 'Site Visit',
            'Symposium' => 'Symposium',
            'Meeting' => null
        };
        
        List<String> subtypes = new List<String>{
            'Classic staff lunch'
        };

        List<Hippo_Event__c> eventsToInsert = new List<Hippo_Event__c>();
        
        Integer i = 0;
        for (String type : typeToExpectedTypeMap.keySet()) {
            for (String subtype : subtypes) {
                Hippo_Event__c evt = new Hippo_Event__c(
                    Name = 'Test FR ' + i,
                    Start_Event_Date__c = System.today(),
                    End_Event_Date__c = System.today(),
                    TrackingNumber__c = 'trk-' + i,
                    Status__c = 'Approved',
                    Type__c = type,
                    Event_subtype__c = subtype,
                    Country__c = countryIdMap.get('France'),
                    Region__c = regionId,
                    Parent_User_Setting__c = userSettingIdMap.get('France'),
                    VIA_HIP_Subtype__c = 'Commercial'
                );
                eventsToInsert.add(evt);
                i++;
            }
        }
        
        Test.startTest();
        insert eventsToInsert;
        Test.stopTest();
        
        List<Medical_Event_vod__c> medEvents = [
            SELECT VIA_Hippo_Event__r.Type__c, VIA_Hippo_Event__r.Event_subtype__c, Event_Type__c, EPD_FR_MED_Event_Subtype__c
            FROM Medical_Event_vod__c
            WHERE VIA_Hippo_Event__c IN :eventsToInsert
        ];
        
        System.assertEquals(eventsToInsert.size(), medEvents.size(), 'All Medical Events should be created.');

        for (Medical_Event_vod__c me : medEvents) {
            String originalType = me.VIA_Hippo_Event__r.Type__c;
            String originalSubtype = me.VIA_Hippo_Event__r.Event_subtype__c;
            String expectedType = typeToExpectedTypeMap.get(originalType);
            
            System.assertEquals(expectedType, me.Event_Type__c, 'Mismatch for Event Type: ' + originalType);
            System.assertEquals(originalSubtype, me.EPD_FR_MED_Event_Subtype__c, 'Mismatch for Subtype: ' + originalSubtype);
        }
            }
    }

}