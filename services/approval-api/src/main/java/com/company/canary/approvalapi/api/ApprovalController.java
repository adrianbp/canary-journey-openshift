package com.company.canary.approvalapi.api;

import com.company.canary.contracts.HookDecisionResponse;
import com.company.canary.approvalapi.service.ApprovalService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@RequestMapping("/v1")
public class ApprovalController {

    private final ApprovalService approvalService;

    public ApprovalController(ApprovalService approvalService) {
        this.approvalService = approvalService;
    }

    @PostMapping("/approvals")
    public ApprovalResponse create(@Valid @RequestBody CreateApprovalRequest request) {
        return approvalService.create(request);
    }

    @GetMapping("/approvals/{id}")
    public ApprovalResponse get(@PathVariable UUID id) {
        return approvalService.get(id);
    }

    @PostMapping("/approvals/{id}/approve")
    public ApprovalResponse approve(@PathVariable UUID id, @Valid @RequestBody ApprovalActionRequest request) {
        return approvalService.approve(id, request);
    }

    @PostMapping("/approvals/{id}/reject")
    public ApprovalResponse reject(@PathVariable UUID id, @Valid @RequestBody ApprovalActionRequest request) {
        return approvalService.reject(id, request);
    }

    @PostMapping("/approvals/resolve")
    public HookDecisionResponse resolve(@Valid @RequestBody ResolveDecisionRequest request) {
        return approvalService.resolveDecision(request);
    }
}
