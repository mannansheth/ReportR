CREATE TABLE IF NOT EXISTS report_status_history (
  id INT NOT NULL AUTO_INCREMENT,
  Rid VARCHAR(20) NOT NULL,
  previousStatus VARCHAR(100) NULL,
  newStatus VARCHAR(100) NOT NULL,
  changedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actorUserID INT NULL,
  source VARCHAR(50) NOT NULL DEFAULT 'system',
  PRIMARY KEY (id),
  KEY report_status_history_rid (Rid),
  CONSTRAINT report_status_history_report_fk FOREIGN KEY (Rid) REFERENCES reports (Rid) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;