ALTER TABLE sessions ADD COLUMN current_revision INTEGER NOT NULL DEFAULT 1;
ALTER TABLE chunks ADD COLUMN cloud_revision INTEGER NOT NULL DEFAULT 1;
CREATE TABLE session_revisions(session TEXT NOT NULL REFERENCES sessions(id), revision INTEGER NOT NULL, request_id TEXT NOT NULL, parent_hash TEXT NOT NULL, parent_sequence INTEGER NOT NULL, created_at TEXT NOT NULL, PRIMARY KEY(session,revision), UNIQUE(session,request_id));
CREATE TABLE snapshots(id TEXT PRIMARY KEY, session TEXT NOT NULL REFERENCES sessions(id), revision INTEGER NOT NULL, sequence_end INTEGER NOT NULL, hash TEXT NOT NULL, created_at TEXT NOT NULL, UNIQUE(session,revision));
CREATE TABLE snapshot_validations(snapshot TEXT PRIMARY KEY REFERENCES snapshots(id), completeness TEXT NOT NULL, eligible INTEGER NOT NULL, reasons TEXT NOT NULL, metrics TEXT NOT NULL, validated_at TEXT NOT NULL);
ALTER TABLE contribution_revisions ADD COLUMN snapshot TEXT REFERENCES snapshots(id);
INSERT INTO snapshots(id,session,revision,sequence_end,hash,created_at) SELECT id||'-initial',id,1,next_sequence,last_hash,created_at FROM sessions WHERE status='finalized';
INSERT INTO snapshot_validations SELECT s.id,v.completeness,v.eligible,v.reasons,v.metrics,v.validated_at FROM snapshots s JOIN validations v ON v.session=s.session;
UPDATE contribution_revisions SET snapshot=(SELECT id FROM snapshots WHERE session=contribution_revisions.session AND revision=1);
CREATE TRIGGER chunk_revision_guard BEFORE INSERT ON chunks BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM sessions WHERE id=NEW.session AND current_revision=NEW.cloud_revision) THEN RAISE(ABORT,'chunk_conflict_or_quota') END;
END;
CREATE TRIGGER snapshot_immutable BEFORE UPDATE ON snapshots BEGIN SELECT RAISE(ABORT,'snapshot_immutable'); END;
ALTER TABLE outbox ADD COLUMN identity_error TEXT;
UPDATE outbox SET target=(SELECT id FROM snapshots WHERE session=outbox.target AND revision=1),generation=generation+1 WHERE kind='validate' AND completed_at IS NULL AND target IN(SELECT session FROM snapshots WHERE revision=1);
ALTER TABLE outbox ADD COLUMN required_validation_bytes INTEGER NOT NULL DEFAULT 0;
CREATE TRIGGER snapshot_count_guard BEFORE INSERT ON snapshots BEGIN
 SELECT CASE WHEN (SELECT count(*) FROM snapshots p JOIN sessions s ON s.id=p.session WHERE s.owner=(SELECT owner FROM sessions WHERE id=NEW.session))>=1000 THEN RAISE(ABORT,'snapshot_quota') END;
END;
CREATE TRIGGER validation_storage_guard BEFORE INSERT ON snapshot_validations BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM snapshot_validations WHERE snapshot=NEW.snapshot) AND COALESCE((SELECT sum(length(CAST(v.metrics AS BLOB))+length(CAST(v.reasons AS BLOB))+500) FROM snapshot_validations v JOIN snapshots p ON p.id=v.snapshot JOIN sessions s ON s.id=p.session WHERE s.owner=(SELECT s2.owner FROM snapshots p2 JOIN sessions s2 ON s2.id=p2.session WHERE p2.id=NEW.snapshot)),0)+length(CAST(NEW.metrics AS BLOB))+length(CAST(NEW.reasons AS BLOB))+500>16777216 THEN RAISE(ABORT,'validation_storage_quota') END;
END;
DELETE FROM validations;
DELETE FROM feedback_revisions;
