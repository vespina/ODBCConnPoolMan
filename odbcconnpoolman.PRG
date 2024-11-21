* ODBCONNPOOLMAN.PRG
* ODBC CONNECTION POOLS MANAGER
*
* AUTHOR: VICTOR ESPINA
* CREATED: NOV 2024
*
#DEFINE CRLF	CHR(13)+CHR(10)


* ODBCConnPoolMan (Class)
* CONNECTION POOLS MANAGER
*
DEFINE CLASS ODBCConnPoolManager AS Custom

	Version = "1.0"
	
	minPoolSize = 1           && MIN NUMBER OF CONNECTIONS ON A POOL 
	maxPoolSize = 50          && MAX NUMBER OF ALLOWED CONNECTIONS ON A POOL
	maxLifeSpan = 15          && MAX AMOUNT OF MINUTES A CONNECTION CAN BE IDLE BEFORE BEING CLOSED
	autoCleanup = .T.         && ACTIVATE/DEACTIVATE AUTO CLEANUP FUNCTION
	autoCleanupInterval = 1   && INTERVAL (IN MINUTES) FOR AUTO CLEANUP
	lastError = ""            && LAST ERROR OCURRED 
	
	HIDDEN aPools[1,2]
	HIDDEN aIndex[1,2]
	HIDDEN Count 
	HIDDEN autoCleanupTimer 
	
	* CLASS CONSTRUCTOR
	PROCEDURE Init
		LPARAMETERS pnMinPoolSize, pnMaxPoolSize
		THIS.minPoolSize = IIF(VARTYPE(pnMinPoolSize) = "N",pnMinPoolSize, THIS.minPoolSize)
		THIS.maxPoolSize = IIF(VARTYPE(pnMaxPoolSize) = "N",pnMaxPoolSize, THIS.maxPoolSize)
		DIMENSION THIS.aPools[1,2]
		THIS.aPools[1,1] = ""
		THIS.aPools[1,2] = NULL
		DIMENSION THIS.aIndex[1,2]
		THIS.aIndex[1,1] = 0 
		THIS.aIndex[1,2] = 0
		THIS.Count = 0
		THIS.lastError = ""
		THIS.autoCleanupTimer = NULL
		THIS.autoCleanup = THIS.autoCleanup	    
		RETURN
		
    * SETTERS
	PROCEDURE autoCleanup_Assign(vNewVal)
	    THIS.autoCleanup = m.vNewVal
		IF m.vNewVal
			THIS.autoCleanupTimer = CREATE("OCPMAutoCleanupTimer")
			THIS.autoCleanupTimer.Manager = THIS
		    THIS.autoCleanupInterval = THIS.autoCleanupInterval		
		    THIS.autoCleanupTimer.Start()
		ELSE
			IF NOT ISNULL(THIS.autoCleanupTimer)
				THIS.autoCleanupTimer.Stop()
				THIS.autoCleanupTimer.Manager = NULL
				THIS.autoCleanupTimer = NULL
			ENDIF
		ENDIF
		RETURN
		
	PROCEDURE autoCleanupInterval_Assign(vNewVal)
		THIS.autoCleanupInterval = m.vNewVal
		IF THIS.autoCleanup AND !ISNULL(THIS.autoCleanupTimer)
			THIS.autoCleanupTimer.Interval = m.vNewVal * 60 * 1000
		ENDIF
		RETURN
		

	* Connect
	* GET A NEW CONNECTION FOR A SPECIFIC CONNECTION STRING
	*
	FUNCTION Connect
		LPARAMETERS pcConnString
		
		* GET A CONNECTION POOL FOR THE CONNECTION STRING
		LOCAL oPool
		oPool = THIS.getPool(pcConnString)
		
		* GET A NEW CONNECTION FROM THE POOL
		LOCAL nConn
		nConn = oPool.Get()
		THIS.lastError = ""
		IF nConn <= 0
			THIS.lastError = oPool.lastError
			RETURN 0
		ENDIF
		
		* ADD THE CONNECTION TO THE INDEX. WE USE THIS INDEX TO 
		* FIND THE POOL FROM WHERE A CONNECTION WAS OBTAINED
		THIS.addToIndex(oPool.Index, nConn)

		* CLEANUP UNUSED CONNECTIONS
		oPool.cleanUp()
		THIS.cleanIndex(oPool)
				
		RETURN nConn
				
		
	
	* Disconnect
	* RETURN A CONNECTION TO THE POOL
	*	
	PROCEDURE Disconnect
		LPARAMETERS pnHODBC
		LOCAL nIndex,nPoolIndex,oPool
		nIndex = THIS.getIndex(pnHODBC)
		nPoolIndex = THIS.aIndex[nIndex, 2]
		oPool = THIS.aPools[nPoolIndex, 2]
		oPool.Dispose(pnHODBC)
		THIS.aIndex[nIndex,1] = 0
		THIS.aIndex[nIndex,2] = NULL
		RETURN
		
		
		
	* getPool
	* RETURNS A REFERENCE FOR THE CONNECTION POOL ASSOCIATED
	* TO A GIVEN CONNECTION STRING
	*	
	FUNCTION getPool
		LPARAMETERS pcConnString
		LOCAL nIndex
		nIndex = THIS.getPoolIndex(pcConnString)
		RETURN THIS.aPools[nIndex, 2]	



	* cleanUp
	* CLOSE EXPIRED UNUSED CONNECTIONS ON ALL POOLS
	*
	PROCEDURE cleanUp()
		LOCAL oPool,i
		FOR i = 1 TO THIS.Count
		    oPool = THIS.aPools[i, 2]
			oPool.cleanUp()
			THIS.cleanIndex(oPool)
		ENDFOR
		RETURN 


	* Reseet
	* CLOSE ALL CONNECTIONS IN ALL POOLS AND CLOSE ALL POOLS
	*
	PROCEDURE Reset
		LOCAL oPool,i
		FOR i = 1 TO THIS.Count
		    oPool = THIS.aPools[i, 2]
			oPool.disposeAll()
			THIS.aPools[i,2] = NULL
		ENDFOR
		SQLDISCONNECT(0)  && SOLO POR SI ACASO
		DIMENSION THIS.aPools[1,2]
		THIS.Count = 0
		RETURN 
	
	
	* Dispose()
	* CLOSE ALL POOLS & CONNECTIONS AND GENERAL CLEANUP
	*
	PROCEDURE Dispose
		THIS.Reset()
		THIS.autoCleanup = .F.
		RETURN
		

	* toString()
	* GENERATES A STRING REPRESENTATION OF THE MANASGER STATE
	*
	PROCEDURE toString()
		LOCAL cOutput,i,oPool
		cOutput = ""
		FOR i = 1 TO THIS.Count
		    oPool = THIS.aPools[i, 2]
			cOutput = cOutput +  ALLT(STR(i)) + ": " + THIS.aPools[i,1] + CRLF + REPL("-",80) + CRLF + oPool.toString() + CRLF
		ENDFOR
		RETURN cOutput
		



	* getPoolIndex
	* RETURN THE INDEX FOR A SPECIFIC CONNECTION STRING
	* IN THE POOL'S ARRAY
	*
	HIDDEN FUNCTION getPoolIndex
		LPARAMETERS pcConnString
		
		* CHECK FOR AN EXISTING POOL
		LOCAL i,nIndex
		nIndex = 0 
		FOR i = 1 TO THIS.Count
			IF THIS.aPools[i,1] == LOWER(pcConnString)
				nIndex = i
				EXIT
			ENDIF
		ENDFOR
		
		* IF NOT FOUND, CREATE A NEW ONE
		IF nIndex = 0 
			THIS.Count = THIS.Count + 1
			nIndex = THIS.Count
			IF THIS.Count > ALEN(THIS.aPools,1)
				DIMENSION THIS.aPools[THIS.Count, 2]
			ENDIF

			LOCAL oPool
			oPool = CREATE("OCPMPool")
			WITH oPool
				.Index = nIndex
				.minPoolSize = THIS.minPoolSize
				.maxPoolSize = THIS.maxPoolSize
				.maxLifeSpan = THIS.maxLifeSpan
				.connString = pcConnSTring
			ENDWITH		
			THIS.aPools[nIndex,1] = LOWER(pcConnString)
			THIS.aPools[nIndex,2] = oPool

		ENDIF
		RETURN nIndex


	* addToIndex
	* ADD A CONNECTION TO THE CONNECTION'S INDEX
	*
	HIDDEN PROCEDURE addToIndex
		LPARAMETERS pnPoolIndex, pnConn
	    LOCAL nIndex,i
	    nIndex = 0 
		FOR i = 1 TO ALEN(THIS.aIndex,1)
			IF THIS.aIndex[i,1] = 0
				nIndex = i
				EXIT
			ENDIF
		ENDFOR
		IF nIndex = 0 
			nIndex = ALEN(THIS.aIndex, 1) + 1
			DIMEN THIS.aIndex[nIndex, 2]
		ENDIF
		THIS.aIndex[nIndex, 1] = pnConn
		THIS.aIndex[nIndex, 2] = pnPoolIndex
		RETURN
		
		
	* getIndex
	* RETURNS THE INDEX FOR A GIVEN CONNECTION
	* IN THE CONNECTIONS INDEX
	*	
	HIDDEN FUNCTION getIndex
		LPARAMETERS phODBC
		LOCAL nIndex,i
		nIndex = 0
		FOR i = 1 TO ALEN(THIS.aIndex, 1)
			IF THIS.aIndex[i,1] = phODBC
				nIndex = i
				EXIT
			ENDIF
		ENDFOR
		RETURN nIndex
			


	* cleanIndex()
	* CHECK THE CONNECTION INDEX FOR CLOSED CONNECTIONS
	*
	HIDDEN PROCEDURE cleanIndex
		LPARAMETERS poPool
		LOCAL i
		FOR i = 1 TO ALEN(THIS.aIndex,1)
			IF THIS.aIndex[i,1] > 0 AND THIS.aIndex[i,2] = poPool.Index
				IF NOT poPool.isConn(THIS.aIndex[i,1])
					THIS.aIndex[i,1] = 0
					THIS.aIndex[i,2] = 0
				ENDIF
			ENDIF
		ENDFOR
		RETURN
				
ENDDEFINE



* OCPMPool
* CONNECTION POOL CLASS
*
DEFINE CLASS OCPMPool AS Custom

	minPoolSize = 1
	maxPoolSize = 50
	maxLifeSpan = 15
	lastError = ""
	Index = 0 
	connString = ""

	HIDDEN aPool[1]	
	HIDDEN Count
	
	PROCEDURE Init
		THIS.aPool[1] = NULL 
		THIS.Count = 0 
		RETURN
		
	
	* Get
	* RETURNS AN AVAILABLE CONNECTION FROM THE POOL
	*
	FUNCTION Get
		LOCAL oConn,i
		oConn = NULL
		THIS.lastError = ""
		IF THIS.Count < THIS.minPoolSize
			FOR i = THIS.Count + 1 TO THIS.minPoolSize
			    oConn = CREATE("OCPMPoolItem", THIS.connString)
			    oConn.Open()
			    IF NOT oConn.Connected
			    	THIS.lastError = "[CONNECT-ERROR] " + oConn.lastError
			    	EXIT
			    ENDIF
			    oConn.Available = oConn.Connected
			    IF i = (THIS.Count + 1)
			    	DIMENSION THIS.aPool[THIS.minPoolSize]
			    ENDIF
				THIS.aPool[i] = oConn 
			ENDFOR
			IF !EMPTY(THIS.lastError)
				RETURN 0
			ENDIF
			THIS.Count = THIS.minPoolSize
		ENDIF
		
		oConn = NULL
		FOR i = 1 TO THIS.Count
			IF THIS.aPool[i].Available
				oConn = THIS.aPool[i]
				EXIT
			ENDIF
		ENDFOR
		DO CASE
		   CASE ISNULL(oConn)
		   		IF THIS.Count < THIS.maxPoolSize
					oConn = CREATE("OCPMPoolItem", THIS.connString)
					IF oConn.Open()
						THIS.Count = THIS.Count + 1 
						DIMEN THIS.aPool[THIS.Count]
						THIS.aPool[THIS.Count] = oConn
					ENDIF
				ELSE
				ENDIF
								
		    CASE oConn.hODBC = 0
		    	 oConn.Open()
		ENDCASE
		THIS.lastError = ""
		IF oConn.Connected
			oConn.Available = .F.
			oConn.lastUsed = DATETIME()
		ELSE
		 	THIS.lastError = oConn.lastError
		ENDIF
		RETURN oConn.hODBC
		
	
	
	* Dispose
	* RELEASE AN USED CONNECTION FROM THE POOL SO IT BECOMES
	* AVAILABLE AGAIN
	*	
	PROCEDURE Dispose
		LPARAMETERS pnHODBC
		LOCAL i,oConn
		FOR i = 1 TO THIS.Count
			oConn = THIS.aPool[i]
			IF oConn.hODBC = pnHODBC
				oConn.Available = .T.
				EXIT
			ENDIF
		ENDFOR
		RETURN



	* isConn()
	* CHECKS IF THE GIVEN CONNECTION EXISTS 
	* IN THE POOL
	*
	FUNCTION isConn
		LPARAMETERS pnConn
		LOCAL i,nIndex,oPool
		nIndex = 0
		FOR i = 1 TO THIS.Count
			oPool = THIS.aPool[i]
			IF oPool.hODBC = pnConn
				nIndex = i
				EXIT
			ENDIF
		ENDFOR
		RETURN (nIndex > 0)


	* disposeAll
	* RELEASE ALL USED CONNECTIONS
	*	
	PROCEDURE disposeAll
		LOCAL i,oConn
		FOR i = 1 TO THIS.Count
			oConn = THIS.aPool[i]
			IF oConn.Connected
				oConn.Close()
			ENDIF
			THIS.aPool[i] = NULL
		ENDFOR
		DIMENSION THIS.aPool[1]
		THIS.Count = 0 
		RETURN


	* cleanUp
	* RELEASE EXPIRED UNUSED CONNECTIONS 
	*
	PROCEDURE cleanUp
		LPARAMETERS plClearAll
		LOCAL i,oConn,nMSLU
		FOR i = 1 TO THIS.Count
			oConn = THIS.aPool[i]
			IF oConn.Available
				nMSLU = (DATETIME() - oConn.lastUsed) / 60
				IF nMSLU > THIS.maxLifeSpan OR plClearAll
					oConn.Close()
				ENDIF
			ENDIF
		ENDFOR
		RETURN
		
		
		
	* toString()
	* RETURN A STRING REPRESENTATION OF THE POOL'S CURRENT STATE
	*	
	PROCEDURE toString
		LOCAL cOutput,i,oConn
		cOutput = ""
		FOR i = 1 TO THIS.COunt
			oConn = THIS.aPool[i]
			cOutput = cOutput + ALLT(STR(i)) + ": [" + IIF(oConn.Available,"A","U") + "] " + ALLT(STR(oConn.hODBC)) + CRLF
		ENDFOR
		RETURN cOutput
ENDDEFINE




* OCPMPoolItem
* REPRESENTS A CONNECTION IN A CONNECTION POOL
* 
DEFINE CLASS OCPMPoolItem AS Custom
	hODBC = 0
	Available = .F.
	connString = ""
	lastUsed = {//::}
	Connected = .F.
	lastError = ""
	
	* CLASS CONSTRUCTOR
	PROCEDURE Init
		LPARAMETERS pcConnString
		THIS.connString = pcConnString
		RETURN
		
	* Open()
	* OPEN CONNECTION
	*	
	PROCEDURE Open
		THIS.hODBC = SQLSTRINGCONNECT(THIS.connString)
		THIS.Connected = (THIS.hODBC > 0)
		IF THIS.Connected
			THIS.lastError = ""
		ELSE
			THIS.lastError = THIS.getLastError()
		ENDIF		
		RETURN
	
	
	* Close()
	* CLOSE THE CONNECTION		
	*
	PROCEDURE Close
		SQLDISCONNECT(THIS.hODBC)
		THIS.hODBC = 0 
		RETURN
	
	
		
	* getLastError()
	* RETURNS THE LAST ODBC ERROR OCURRED	
	*
	FUNCTION getLastError
		LOCAL ARRAY aErrInfo[1]
		AERROR(aErrInfo)
		RETURN aErrInfo[1,2]
ENDDEFINE


* OCPMAutoCleanupTimer
* CONNECTIONS AUTO CLEANUP TIMER
*
DEFINE CLASS OCPMAutoCleanupTimer AS Timer
	Interval = 15 * 60 * 1000
	Enabled = .F.
	Manager = NULL
	
	* CLASS CONSTRUCTOR
	PROCEDURE Init
		THIS.Manager = NULL
		RETURN
		
	* Start()
	* START THE TIMER
	*	
	PROCEDURE Start
		THIS.Enabled = .T.
		RETURN
	
	* Stop()
	* STOP THE TIMER
	*	
	PROCEDURE Stop
		THIS.Enabled = .F.
		RETURN
	
	
	* Timer()
	* TIMER EVENT HANDLER
	*	
	PROCEDURE Timer
		THIS.Stop()
		IF NOT ISNULL(THIS.Manager)
			THIS.Manager.cleanUp()
		ENDIF
		THIS.Start()
		RETURN
ENDDEFINE
