package com.company.canary.approvalapi.persistence;

import com.company.canary.approvalapi.domain.ApprovalRequestEntity;
import com.company.canary.contracts.StepType;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface ApprovalRequestRepository extends JpaRepository<ApprovalRequestEntity, UUID> {

    Optional<ApprovalRequestEntity> findTopByClusterAndNamespaceAndCanaryNameAndRevisionAndStepTypeOrderByRequestedAtDesc(
            String cluster,
            String namespace,
            String canaryName,
            String revision,
            StepType stepType
    );
}
