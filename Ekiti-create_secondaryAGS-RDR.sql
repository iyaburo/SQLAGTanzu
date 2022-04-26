--Add_Secondary2
USE [master]
GO
--Create login for AG
-- it should match the password from the primary script
CREATE LOGIN ag_login WITH PASSWORD = 'VMware123456!';
CREATE USER ag_user FOR LOGIN ag_login;
-- create certificate
-- this time, create the certificate using the certificate file created in the primary node
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'VMware123456!';
GO
-- Create the certificate using the certificate file created in the primary node
CREATE CERTIFICATE ekiti_rdr_cert
    AUTHORIZATION ag_user
    FROM FILE = '/var/opt/mssql/ekiti_rdr_cert.cert'
    WITH PRIVATE KEY (
    FILE = '/var/opt/mssql/ekiti_rdr_cert.key',
    DECRYPTION BY PASSWORD = 'VMware123456!'
)
GO
--create HADR endpoint
CREATE ENDPOINT [AG_endpoint]
STATE=STARTED
AS TCP (
    LISTENER_PORT = 5022,
    LISTENER_IP = ALL
)
FOR DATA_MIRRORING (
    ROLE = ALL,
    AUTHENTICATION = CERTIFICATE ekiti_rdr_cert,
    ENCRYPTION = REQUIRED ALGORITHM AES
)
GRANT CONNECT ON ENDPOINT::AG_endpoint TO [ag_login];
GO
--add current node to the availability group
ALTER AVAILABILITY GROUP [ekiti-Test-AG-RDR] JOIN WITH (CLUSTER_TYPE = NONE)
ALTER AVAILABILITY GROUP [ekiti-Test-AG-RDR] GRANT CREATE ANY DATABASE
GO