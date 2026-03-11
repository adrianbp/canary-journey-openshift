package com.company.canary.approvalapi.api;

import com.company.canary.approvalapi.domain.ApprovalRequestEntity;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

@Component
public class ServiceNowTaskClient {

    private static final Logger LOGGER = LoggerFactory.getLogger(ServiceNowTaskClient.class);

    public void onApprovalCreated(ApprovalRequestEntity entity) {
        LOGGER.info("ServiceNow stub create/update task for approval {} and task {}", entity.getId(), entity.getSnowTaskId());
    }

    public void onApprovalDecision(ApprovalRequestEntity entity) {
        LOGGER.info("ServiceNow stub sync decision {} for approval {}", entity.getStatus(), entity.getId());
    }
}
