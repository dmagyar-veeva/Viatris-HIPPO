trigger VI_VEEV_HippoHCPTrigger on Event_HCP__c (before insert, before update, before delete, after insert, after update, after delete, after undelete) {
    VI_VEEV_TriggerDispatcher.run(new VI_VEEV_HippoHCPTriggerHandler());
}