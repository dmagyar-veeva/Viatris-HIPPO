trigger VI_VEEV_HippoEventTrigger on Hippo_Event__c (before insert, before update, before delete, after insert, after update, after delete, after undelete) {
    VI_VEEV_TriggerDispatcher.run(new VI_VEEV_HippoEventTriggerHandler());
}