# ODBCConnPoolMan
ODBC Connection Pools Manager

Version: 1.0
Author : Victor Espina


### HOW TO USE


#### INITIALIZATION

    SET PROCEDURE TO OBBCConnPoolMan ADDITIVE
    PUBLIC goCPM  && FEEL FREE TO USE YOUR OWN NAME
    goCPM = CREATE("ODBCConnPoolManager")
    WITH goCPM
        .minPoolSize = 5    && SET THE MINIMUN AMOUNT OF OPEN CONNECTIONS PER POOL
        .maxPoolSize = 50   && SET THE MAXIMUM AMOUNT OF OPEN CONNECTIONS PER POOL
        .maxLifeSpan = 15   && MAX NUMBER OF MINUTES A CONNECTION WILL BE KEPT OPEN AFTER BEING RETURNED TO THE POOL
    ENDWITH
        
        

#### GET A NEW CONNECTION

    LOCAL nConn
    nConn = goCPM.Connect("connection-string")
    
#### RELEASE A CONNECTION

    goCPM.Disconnect(nConn)
    
#### RELEASE CONNECTION MANAGER

    goCPM.Dispose() && CALL THIS BEFORE CLOSING YOUR APP
    
#### AUTO CLEANUP FEATURE
Normally, the connection manager will cleanup unused connections after every call to Connect(), but you can also activate
the auto-cleanup function, so unused connections would be released after a certain amount of time, even if no calls to Connect() occurs.

    goCPM.autoCleanupInterva = 15   && INTERVAL TIME (IN MINUTES)
    goCPM.autoCleanup = .T.         && ACTIVATE AUTO-CLEANUP FEATURE
    ...
    goCPM.autoCleanup = .F.         && DEACTIVATE AUTO-CLEANUP FEATURE
    
    