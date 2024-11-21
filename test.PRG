* TEST.PRG
* ODBC COnnection Manager test
*
CLOSE ALL
CLEAR ALL
CLEAR


SET PROC TO ODBCConnPoolMan


SET MEMOWIDTH TO 200


* DEFINE A COUPLE OF VALID CONNECTION STRINGS
LOCAL cConnStr1,cConnStr2
cConnStr1 = "Driver={SQL Server};server=valar;uid=sa;pwd=sa**2019;database=dnpsa;"
cConnStr2 = "Driver={SQL Server};server=valar;uid=sa;pwd=sa**2019;database=easymaxsync;"

* DEFINE AN INVALID CONNECTION STRING
LOCAL cConnStr3
cConnStr3 = "server=foo;"


* INITIALIZE MANAGER 
LOCAL oCPM
oCPM = CREATE("ODBCConnPoolManager")
oCPM.autoCleanup = .F.   && DEACTIVATE AUTO-CLEANUP FOR TESTING
oCPM.maxLifeSpan = 1     && SET CONNECTION MAX LIFE SPAN TO 1 MIN

?"ODBC Connection Pool Manager " + oCPM.Version
?"TEST PROGRAM"
?


* CREATE SOME VALID CONNECTIONS
?"* Getting connection (connStr1): ",oCPM.Connect(cConnStr1)
?"* Getting connection (connStr1): ",oCPM.Connect(cConnStr1)

LOCAL nConn2
nConn2 = oCPM.Connect(cConnStr2)
?"* Getting connection (connStr2): ",nConn2


* SHOW MANAGER STATE
MESSAGEBOX(oCPM.toString(),0,"TEST 1")


* CLOSE A CONNECTION. THE CONNECTION ITSELF REMAINS OPEN
* BUT FLAGGED AS [A]VAILABLE
?"* Closing connection",nConn2
oCPM.Disconnect(nConn2)

* SHOW MANAGER STATE
MESSAGEBOX(oCPM.toString(),0,"TEST 2")

* GET A NEW CONNECTION FROM THE SAME CONNECTION STRING SO WE
* CAN CHECK WE GET THE SAME CONNECTION ID 
?"* Getting connection (connStr2): ",oCPM.Connect(cConnStr2)

* SHOW MANAGER STATE
MESSAGEBOX(oCPM.toString(),0,"TEST 3")


* NOW WE CLOSE THE LAST CONNECTION AGAIN AND ACTIVATE AUTO-CLEANUP FEATURE
?"* Closing connection",nConn2
oCPM.Disconnect(nConn2)

?"* Activating auto-cleanup..."
oCPM.autoCleanupInterval = 1.5
oCPM.autoCleanup = .T.
??"Done!"

?"* Waiting 90s for auto-cleaning (press any key to abort)..."
INKEY(95,'H')
??"Done!"

* SHOW MANAGER STATE
MESSAGEBOX(oCPM.toString(),0,"TEST 4")


* RESET MANAGER. ALL CONNECTIONS & POOLS WILL BE CLOSED
?"* Closing all connections in all pools"
oCPM.Reset()

* SHOW MANAGER STATE
MESSAGEBOX(oCPM.toString(),0,"TEST 5")


* SHOW ERROR HANDLING
?"* Getting a connection (invalid conn string)..."
nConn2 = oCPM.Connect(cConnStr3)
IF nConn2 = 0
	??oCPM.lastError
ENDIF


* CLEANUP MANAGER
?"* Cleaning up..."
oCPM.Dispose()
oCPM = NULL
??"Done!"



