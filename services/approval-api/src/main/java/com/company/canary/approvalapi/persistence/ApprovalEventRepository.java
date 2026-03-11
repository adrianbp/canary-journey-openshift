package com.company.canary.approvalapi.persistence;

import com.company.canary.approvalapi.domain.ApprovalEventEntity;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ApprovalEventRepository extends JpaRepository<ApprovalEventEntity, Long> {
}
