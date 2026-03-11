package com.company.canary.approvalapi.persistence;

import com.company.canary.approvalapi.domain.IdempotencyKeyEntity;
import org.springframework.data.jpa.repository.JpaRepository;

public interface IdempotencyKeyRepository extends JpaRepository<IdempotencyKeyEntity, String> {
}
