/**
 * @description       :
 * @author            : melita.calis@veeva.com
 * @group             :
 * @last modified on  : 08-12-2021
 * @last modified by  : melita.calis@veeva.com
 * Modifications Log
 * Ver   Date         Author                   Modification
 * 1.0   08-12-2021   melita.calis@veeva.com   Initial Version
 *
 **********************************************************************
 *
 *               Confidentiality Information:
 *
 * This module is based on pre-existing content developed and owned
 * by Veeva Systems Inc.; this may only be used in connection with the
 * deliverable with which it was provided to Customer.
 *
 * Copyright (c) 2019 Veeva Systems, Inc.  All Rights Reserved.
 *
 **********************************************************************/
public interface VI_VEEV_IFACE_TriggerHandler {
    void onBeforeInsert(List<SObject> newItems);
    void onBeforeUpdate(List<SObject> oldItems, List<SObject> newItems, Map<Id, SObject> oldItemsMap, Map<Id, SObject> newItemsMap);
    void onBeforeDelete(List<SObject> oldItems);
    void onAfterInsert(List<SObject> newItems, Map<Id, SObject> newItemsMap);
    void onAfterUpdate(List<SObject> oldItems, List<SObject> newItems, Map<Id, SObject> oldItemsMap, Map<Id, SObject> newItemsMap);
    void onAfterDelete(List<SObject> oldItems, Map<Id, SObject> oldItemsMap);
    void onAfterUndelete(List<SObject> oldItems, Map<Id, SObject> oldItemsMap);
    Boolean isDisabled();
}