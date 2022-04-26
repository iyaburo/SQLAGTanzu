-- Create AG test database
USE [master]
GO
CREATE DATABASE "ekiti-Test-DB-RDR"
GO
USE [ekiti-Test-DB-RDR]
GO
CREATE TABLE Customers([CustomerID] int NOT NULL, [CustomerName] varchar(30) NOT NULL)
GO
INSERT INTO Customers (CustomerID, CustomerName) VALUES (30,'ABC CO'),(90,'BBC CO'),(130,'CNN CO)')
-- Change DB recovery model to Full and take full backup
ALTER DATABASE [ekiti-Test-DB-RDR] SET RECOVERY FULL ;
GO
BACKUP DATABASE [ekiti-Test-DB-RDR] TO  DISK = N'/var/opt/mssql/backup/ekiti-Test-DB-RDR.bak' WITH NOFORMAT, NOINIT,  NAME = N'ekiti-Test-DB-RDR-Full Database Backup', SKIP, NOREWIND, NOUNLOAD,  STATS = 10
GO
USE [master]
GO
--create logins for AG
CREATE LOGIN ag_login WITH PASSWORD = 'VMware123456!';
CREATE USER ag_user FOR LOGIN ag_login;
-- Create a master key and certificate
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'VMware123456!';
GO
CREATE CERTIFICATE ekiti_rdr_cert WITH SUBJECT = 'SQNux AG Certificate';
-- Copy these two files to the same directory on secondary replicas
BACKUP CERTIFICATE ekiti_rdr_cert
TO FILE = '/var/opt/mssql/ekiti_rdr_cert.cert'
WITH PRIVATE KEY (
        FILE = '/var/opt/mssql/ekiti_rdr_cert.key',
        ENCRYPTION BY PASSWORD = 'VMware123456!'
    );
GO
-- Create AG endpoint on port 5022
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
--Create AG primary replica
USE [master]
GO
CREATE AVAILABILITY GROUP [ekiti-Test-AG-RDR]   
     WITH ( CLUSTER_TYPE =  NONE )  
   FOR REPLICA ON   
      N'ekiti-rdr-pri' WITH   
         (  
         ENDPOINT_URL = N'tcp://ekiti-rdr-pri-7d8dd66cd9-smktv.tsalab.local:5022',
         AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
         SEEDING_MODE = AUTOMATIC,
         FAILOVER_MODE = MANUAL,  
         SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL,   
            READ_ONLY_ROUTING_URL = N'TCP://ekiti-rdr-pri-7d8dd66cd9-smktv.tsalab.local:1433' ),
         PRIMARY_ROLE (ALLOW_CONNECTIONS = READ_WRITE,   
            READ_ONLY_ROUTING_LIST = ('ekiti-rdr-sec1', 'ekiti-rdr-sec2'),
            READ_WRITE_ROUTING_URL = N'TCP://ekiti-rdr-pri-7d8dd66cd9-smktv.tsalab.local:1433' ),   
         SESSION_TIMEOUT = 10  
         ),   
      N'ekiti-rdr-sec1' WITH   
         (  
         ENDPOINT_URL = N'TCP://ekiti-rdr-sec1-59f8c9556f-v6pvx.tsalab.local:5022',  
         AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
         SEEDING_MODE = AUTOMATIC,
         FAILOVER_MODE = MANUAL, 
         SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL,   
            READ_ONLY_ROUTING_URL = N'TCP://ekiti-rdr-sec1-59f8c9556f-v6pvx.tsalab.local:1433' ),  
         PRIMARY_ROLE (ALLOW_CONNECTIONS = READ_WRITE,   
            READ_ONLY_ROUTING_LIST = ('ekiti-rdr-pri', 'ekiti-rdr-sec2'),  
            READ_WRITE_ROUTING_URL = N'TCP://ekiti-rdr-sec1-59f8c9556f-v6pvx.tsalab.local:1433' ),
         SESSION_TIMEOUT = 10  
         ),   
      N'ekiti-rdr-sec2' WITH   
         (  
         ENDPOINT_URL = N'TCP://ekiti-rdr-sec2-76bc6bc9fc-hzzws.tsalab.local:5022',  
         AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
         SEEDING_MODE = AUTOMATIC,
         FAILOVER_MODE = MANUAL,  
         SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL,   
            READ_ONLY_ROUTING_URL = N'TCP://ekiti-rdr-sec2-76bc6bc9fc-hzzws.tsalab.local:1433' ),  
         PRIMARY_ROLE (ALLOW_CONNECTIONS = READ_WRITE,   
            READ_ONLY_ROUTING_LIST = ('ekiti-rdr-pri', 'ekiti-rdr-sec1'),  
            READ_WRITE_ROUTING_URL = N'TCP://ekiti-rdr-sec2-76bc6bc9fc-hzzws.tsalab.local:1433' ),
         SESSION_TIMEOUT = 10  
         );

-- Add database to AG
USE [master]
GO
ALTER AVAILABILITY GROUP [ekiti-Test-AG-RDR] ADD DATABASE [ekiti-Test-DB-RDR]
GO