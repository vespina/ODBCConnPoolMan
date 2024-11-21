close all
clear all
clear

SET PROC TO ODBCConnPoolMan


SET MEMOWIDTH TO 200


* DEFINA DOS CADENAS DE CONEXION DISTINTAS
LOCAL cConnStr1,cConnStr2
cConnStr1 = "Driver={SQL Server};server=valar;uid=sa;pwd=sa**2019;database=dnpsa;"
cConnStr2 = "Driver={SQL Server};server=valar;uid=sa;pwd=sa**2019;database=easymaxsync;"

* DEFINA UNA CADENA ADICIONAL QUE SEA INCORRECTA
LOCAL cConnStr3
cConnStr3 = "server=foo;"


* INSTANCIAMOS LA CLASE
LOCAL oCPM
oCPM = CREATE("ODBCConnPoolManager")
oCPM.autoCleanup = .F.   && DESACTIVAMOS LA FUNCION DE AUTOCLEANUP
oCPM.maxLifeSpan = 1     && FIJAMOS EL TIEMPO MAXIMO DE OCIO DE UNA CONEXION EN 1 MIN


* CREAMOS ALGUNAS CONEXIONES CON LOS CONNSTRING VALIDOS (1 Y 2)
?"* Obteniendo conexion (connStr1): ",oCPM.Connect(cConnStr1)
?"* Obteniendo conexion (connStr1): ",oCPM.Connect(cConnStr1)

LOCAL nConn2
nConn2 = oCPM.Connect(cConnStr2)
?"* Obteniendo conexion (connStr2): ",nConn2

* MOSTRAMOS EL ESTADO DEL POOL MANAGER
MESSAGEBOX(oCPM.toString(),0,"TEST 1")


* CERRAMOS UNA CONEXION. LA CONEXION EN SI SE MANTENDRA ABIERTA
* PERO SERA MARCADA COMO DISPONIBLE ([A])
?"* Cerrando conexion",nConn2
oCPM.Disconnect(nConn2)

* MOSTRAMOS EL ESTADO DEL POOL MANAGER
MESSAGEBOX(oCPM.toString(),0,"TEST 2")

* AHORA SOLICITAMOS UNA NUEVA CONEXION PARA LA CADENA DE CONEXION
* ASOCIADA CON LA CONEXION QUE ACABAMOS DE CERRAR.  NOS DEBE 
* DEVOLVER EL MISMO ID DE CONEXION QUE TENIAMOS ANTES
?"* Obteniendo conexion (connStr2): ",oCPM.Connect(cConnStr2)

* MOSTRAMOS EL ESTADO DEL POOL MANAGER
MESSAGEBOX(oCPM.toString(),0,"TEST 3")


* CERRAMOS DE NUEVO LA CONEXION Y ACTIVAMOS LA FUNCION DE AUTOCLEANUP
?"* Cerrando conexion",nConn2
oCPM.Disconnect(nConn2)

?"* Activando funcion auto-cleanup..."
oCPM.autoCleanupInterval = 1.5
oCPM.autoCleanup = .T.
??"Done!"

?"* Esperando 90s por auto-cleanup..."
INKEY(95,'H')
??"Done!"

* MOSTRAMOS EL ESTADO DEL POOL MANAGER
MESSAGEBOX(oCPM.toString(),0,"TEST 4")


* REINICIAMOS EL MANAGER.  AL HACER ESTO SE CIERRAN TODAS LAS CONEXIONES
* Y SE LIMPIAN TODOS LOS POOLS
?"* CErrando todas las conexiones"
oCPM.Reset()

* MOSTRAMOS EL ESTADO DEL POOL MANAGER
MESSAGEBOX(oCPM.toString(),0,"TEST 5")


* FINALIZAMOS EL MANAGER (IMPORTANTE)
oCPM.Dispose()

