ALTER TABLE users
  ADD COLUMN role VARCHAR(30) NOT NULL DEFAULT 'Citizen';

ALTER TABLE reports
  ADD COLUMN resolutionNote TEXT NULL,
  ADD COLUMN resolvedAt DATETIME NULL,
  ADD COLUMN resolvedBy INT NULL;

-- Provision authority accounts explicitly through a controlled SQL/development script.
-- Existing users remain Citizen by default.
