trigger VI_VEEV_MedicalEventTrigger on Medical_Event_vod__c(before insert, before update, before delete, after insert, after update, after delete, after undelete) {
    VI_VEEV_TriggerDispatcher.run(new VI_VEEV_MedicalEventTriggerHandler());
}
