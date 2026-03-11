package com.company.canary.approvalapi.service;

import com.company.canary.approvalapi.api.ApprovalActionRequest;
import com.company.canary.approvalapi.api.ApprovalResponse;
import com.company.canary.approvalapi.api.CreateApprovalRequest;
import com.company.canary.approvalapi.api.ServiceNowTaskClient;
import com.company.canary.approvalapi.domain.ApprovalRequestEntity;
import com.company.canary.approvalapi.persistence.ApprovalEventRepository;
import com.company.canary.approvalapi.persistence.ApprovalRequestRepository;
import com.company.canary.approvalapi.persistence.IdempotencyKeyRepository;
import com.company.canary.contracts.ApprovalStatus;
import com.company.canary.contracts.StepType;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.OffsetDateTime;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ApprovalServiceTest {

    @Mock
    private ApprovalRequestRepository approvalRequestRepository;

    @Mock
    private ApprovalEventRepository approvalEventRepository;

    @Mock
    private IdempotencyKeyRepository idempotencyKeyRepository;

    @Mock
    private ServiceNowTaskClient serviceNowTaskClient;

    private ApprovalService approvalService;

    @BeforeEach
    void setUp() {
        approvalService = new ApprovalService(
                approvalRequestRepository,
                approvalEventRepository,
                idempotencyKeyRepository,
                new ApprovalMapper(),
                serviceNowTaskClient
        );
    }

    @Test
    void shouldApproveRequestedState() {
        UUID id = UUID.randomUUID();
        ApprovalRequestEntity entity = new ApprovalRequestEntity();
        entity.setId(id);
        entity.setCluster("eks-main");
        entity.setNamespace("team-a");
        entity.setCanaryName("payments-api");
        entity.setRevision("rev-1");
        entity.setStepType(StepType.CONFIRM_PROMOTION);
        entity.setStatus(ApprovalStatus.REQUESTED);
        entity.setRequestedBy("alice");
        entity.setRequestedAt(OffsetDateTime.now());
        entity.setExpiresAt(OffsetDateTime.now().plusMinutes(30));

        when(approvalRequestRepository.findById(id)).thenReturn(Optional.of(entity));
        when(approvalRequestRepository.save(any(ApprovalRequestEntity.class))).thenAnswer(invocation -> invocation.getArgument(0));
        when(idempotencyKeyRepository.findById("idem-1")).thenReturn(Optional.empty());

        ApprovalResponse response = approvalService.approve(id, new ApprovalActionRequest("bob", "approved", "idem-1"));

        assertThat(response.status()).isEqualTo(ApprovalStatus.APPROVED);
        assertThat(response.decisionBy()).isEqualTo("bob");
        verify(serviceNowTaskClient).onApprovalDecision(any(ApprovalRequestEntity.class));
    }

    @Test
    void shouldCreateRequestedApproval() {
        when(approvalRequestRepository.save(any(ApprovalRequestEntity.class))).thenAnswer(invocation -> invocation.getArgument(0));

        approvalService.create(new CreateApprovalRequest(
                "eks-main", "team-a", "payments-api", "rev-1", StepType.ROLLOUT, "alice", 15, "TASK001"
        ));

        ArgumentCaptor<ApprovalRequestEntity> captor = ArgumentCaptor.forClass(ApprovalRequestEntity.class);
        verify(approvalRequestRepository).save(captor.capture());
        assertThat(captor.getValue().getStatus()).isEqualTo(ApprovalStatus.REQUESTED);
        verify(serviceNowTaskClient).onApprovalCreated(any(ApprovalRequestEntity.class));
        verify(serviceNowTaskClient, never()).onApprovalDecision(any(ApprovalRequestEntity.class));
    }
}
