/**
 * @description       : Trigger handler for Hippo Event trigger
 * @author            : zoltan.nagy@veeva.com
 * @group             : 
 * @last modified on  : 11-01-2022
 * @last modified by  : zoltan.nagy@veeva.com
**/
public with sharing class VI_VEEV_HippoEventTriggerHandler implements VI_VEEV_IFACE_TriggerHandler {

    public void onBeforeInsert(List<SObject> newItems) 
    {

    }
    public void onBeforeUpdate(List<SObject> oldItems, List<SObject> newItems, Map<Id, SObject> oldItemsMap, Map<Id, SObject> newItemsMap) 
    {

    }
    public void onBeforeDelete(List<SObject> oldItems) 
    {

    }
    public void onAfterInsert(List<SObject> newItems, Map<Id, SObject> newItemsMap) 
    {
        // create Medical Events from Hippo Events created.
        VI_VEEV_HippoEventCloneHelper.createMedicalEvents(newItems);
    }
    public void onAfterUpdate(List<SObject> oldItems, List<SObject> newItems, Map<Id, SObject> oldItemsMap, Map<Id, SObject> newItemsMap) 
    {
        // update Medical Events following Hippo Events changes.
        VI_VEEV_HippoEventCloneHelper.updateMedicalEvents(oldItemsMap, newItemsMap);
    } 
    public void onAfterDelete(List<SObject> oldItems, Map<Id, SObject> oldItemsMap) {

    }
    public void onAfterUndelete(List<SObject> oldItems, Map<Id, SObject> oldItemsMap) {

    }
    public Boolean isDisabled() {
        return false;
    }
}