package com.company.canary.approvalapi.service;

import com.company.canary.approvalapi.api.ApprovalActionRequest;
import com.company.canary.approvalapi.api.ApprovalResponse;
import com.company.canary.approvalapi.api.CreateApprovalRequest;
import com.company.canary.approvalapi.api.ResolveDecisionRequest;
import com.company.canary.approvalapi.api.ServiceNowTaskClient;
import com.company.canary.approvalapi.domain.ApprovalEventEntity;
import com.company.canary.approvalapi.domain.ApprovalRequestEntity;
import com.company.canary.approvalapi.domain.IdempotencyKeyEntity;
import com.company.canary.approvalapi.persistence.ApprovalEventRepository;
import com.company.canary.approvalapi.persistence.ApprovalRequestRepository;
import com.company.canary.approvalapi.persistence.IdempotencyKeyRepository;
import com.company.canary.contracts.ApprovalStatus;
import com.company.canary.contracts.HookDecisionResponse;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.OffsetDateTime;
import java.util.Objects;
import java.util.UUID;

@Service
public class ApprovalService {

    private final ApprovalRequestRepository approvalRequestRepository;
    private final ApprovalEventRepository approvalEventRepository;
    private final IdempotencyKeyRepository idempotencyKeyRepository;
    private final ApprovalMapper mapper;
    private final ServiceNowTaskClient serviceNowTaskClient;

    public ApprovalService(
            ApprovalRequestRepository approvalRequestRepository,
            ApprovalEventRepository approvalEventRepository,
            IdempotencyKeyRepository idempotencyKeyRepository,
            ApprovalMapper mapper,
            ServiceNowTaskClient serviceNowTaskClient
    ) {
        this.approvalRequestRepository = approvalRequestRepository;
        this.approvalEventRepository = approvalEventRepository;
        this.idempotencyKeyRepository = idempotencyKeyRepository;
        this.mapper = mapper;
        this.serviceNowTaskClient = serviceNowTaskClient;
    }

    @Transactional
    public ApprovalResponse create(CreateApprovalRequest request) {
        ApprovalRequestEntity entity = new ApprovalRequestEntity();
        entity.setId(UUID.randomUUID());
        entity.setCluster(request.cluster());
        entity.setNamespace(request.namespace());
        entity.setCanaryName(request.canaryName());
        entity.setRevision(request.revision());
        entity.setStepType(request.stepType());
        entity.setStatus(ApprovalStatus.REQUESTED);
        entity.setRequestedBy(request.requestedBy());
        entity.setRequestedAt(OffsetDateTime.now());
        entity.setExpiresAt(OffsetDateTime.now().plusMinutes(request.ttlMinutes()));
        entity.setSnowTaskId(request.snowTaskId());

        ApprovalRequestEntity saved = approvalRequestRepository.save(entity);
        writeEvent(saved.getId(), "approval.requested", request.requestedBy(), "{}");
        serviceNowTaskClient.onApprovalCreated(saved);
        return mapper.toResponse(saved);
    }

    @Transactional(readOnly = true)
    public ApprovalResponse get(UUID id) {
        return mapper.toResponse(findById(id));
    }

    @Transactional
    public ApprovalResponse approve(UUID id, ApprovalActionRequest action) {
        return transition(id, action, ApprovalStatus.APPROVED, "approval.approved");
    }

    @Transactional
    public ApprovalResponse reject(UUID id, ApprovalActionRequest action) {
        return transition(id, action, ApprovalStatus.REJECTED, "approval.rejected");
    }

    @Transactional
    public HookDecisionResponse resolveDecision(ResolveDecisionRequest request) {
        ApprovalRequestEntity entity = approvalRequestRepository
                .findTopByClusterAndNamespaceAndCanaryNameAndRevisionAndStepTypeOrderByRequestedAtDesc(
                        request.cluster(),
                        request.namespace(),
                        request.canaryName(),
                        request.revision(),
                        request.stepType())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Approval request not found"));

        expireIfNeeded(entity);

        return new HookDecisionResponse(entity.getStatus(), entity.getDecisionReason());
    }

    private ApprovalResponse transition(UUID id, ApprovalActionRequest action, ApprovalStatus targetStatus, String eventType) {
        ApprovalRequestEntity entity = findById(id);
        expireIfNeeded(entity);

        String requestHash = id + ":" + targetStatus + ":" + Objects.toString(action.reason(), "");
        idempotencyKeyRepository.findById(action.idempotencyKey()).ifPresent(existing -> {
            if (!existing.getRequestHash().equals(requestHash)) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "Idempotency key conflict");
            }
        });

        if (entity.getStatus() == targetStatus) {
            return mapper.toResponse(entity);
        }

        if (entity.getStatus() != ApprovalStatus.REQUESTED) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Cannot transition non-requested approval");
        }

        entity.setStatus(targetStatus);
        entity.setDecisionBy(action.actor());
        entity.setDecisionReason(action.reason());
        entity.setDecidedAt(OffsetDateTime.now());
        ApprovalRequestEntity saved = approvalRequestRepository.save(entity);

        IdempotencyKeyEntity idempotency = new IdempotencyKeyEntity();
        idempotency.setKey(action.idempotencyKey());
        idempotency.setScope("approval-action");
        idempotency.setRequestHash(requestHash);
        idempotency.setResponseSnapshot(saved.getStatus().name());
        idempotency.setExpiresAt(OffsetDateTime.now().plusHours(24));
        idempotencyKeyRepository.save(idempotency);

        writeEvent(saved.getId(), eventType, action.actor(), "{}");
        serviceNowTaskClient.onApprovalDecision(saved);
        return mapper.toResponse(saved);
    }

    private ApprovalRequestEntity findById(UUID id) {
        return approvalRequestRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Approval request not found"));
    }

    private void expireIfNeeded(ApprovalRequestEntity entity) {
        if (entity.getStatus() == ApprovalStatus.REQUESTED && OffsetDateTime.now().isAfter(entity.getExpiresAt())) {
            entity.setStatus(ApprovalStatus.EXPIRED);
            entity.setDecidedAt(OffsetDateTime.now());
            entity.setDecisionReason("TTL expired");
            approvalRequestRepository.save(entity);
            writeEvent(entity.getId(), "approval.expired", "system", "{}");
            serviceNowTaskClient.onApprovalDecision(entity);
        }
    }

    private void writeEvent(UUID approvalId, String eventType, String actor, String payload) {
        ApprovalEventEntity event = new ApprovalEventEntity();
        event.setApprovalId(approvalId);
        event.setEventType(eventType);
        event.setActor(actor);
        event.setPayload(payload);
        event.setCreatedAt(OffsetDateTime.now());
        approvalEventRepository.save(event);
    }
}
