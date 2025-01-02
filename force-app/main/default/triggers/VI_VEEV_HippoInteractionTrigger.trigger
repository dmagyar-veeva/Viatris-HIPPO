trigger VI_VEEV_HippoInteractionTrigger on Hippo_Interaction__c(before insert, before update, before delete, after insert, after update, after delete, after undelete) {
    VI_VEEV_TriggerDispatcher.run(new VI_VEEV_HippoInteractionTriggerHandler());
}