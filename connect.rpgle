**FREE
ctl-opt DftActGrp(*No) option (*srcstmt : *nodebugio : *nounref);
// ==================================================================================
// In order to compile this program run:
// CRTSQLRPGI OBJ(CONNECT) SRCSTMF('/path/to/your/src/connect.rpgle')
// Before running the program add environment variable with fiscal id
// for connection, for example:
// ADDENVVAR ENVVAR(ACUBE_FISCALID) VALUE('LMBFNC')
// ==================================================================================

// ==================================================================================
// Variables
// ==================================================================================
dcl-s WebServiceUrl    varchar(2048) inz;
dcl-s WebServiceHeader varchar(2048) inz;
dcl-s WebServiceBody   varchar(2048) inz;
dcl-s Token            varchar(2048) inz;
dcl-s Text             varchar(2048) inz;
dcl-s FiscalId         varchar(2048) inz;

// A ds that will contain data from JSON response
dcl-ds jsonData   qualified;
  connectUrl   varchar(2048);
end-ds;

// ==================================================================================
// External utilities
// ==================================================================================
dcl-pr getenv pointer extproc('getenv');
  *n pointer value options(*string:*trim);
end-pr;

// ==================================================================================
//                             Main program
// ==================================================================================

// ================ SetUp  vars
FiscalId = %str(getenv('ACUBE_FISCALID'));
WebServiceUrl = 'https://ob-sandbox.api.acubeapi.com/' +
               'business-registry/' + FiscalId + '/connect';

Token = %str(getenv('ACUBE_TOKEN'));

WebServiceHeader = '<httpHeader> ' +
                  '  <header name="authorization" value="bearer ' + Token + '" /> ' +
                  '  <header name="accept" value="application/json" /> ' +
                  '  <header name="content-type" value="application/json" /> ' +                                              
                  '</httpHeader>';

WebServiceBody = '{"locale": "it"}';

// ================ Consume Web service
Exec sql
    Declare Csr01 Cursor For
     Select * from
       Json_Table(Systools.HttpPostClob(:WebServiceUrl, :WebServiceHeader,
                                        :WebServiceBody),
       '$'
       Columns(ConnectUrl VarChar(2048)  Path '$.connectUrl'));
    
Exec Sql Open  Csr01;

DoU 1 = 0;
  Exec Sql
         Fetch Next From Csr01 into :jsonData;

  If SqlCode < *Zeros or SqlCode = 100;
    If SqlCode < *Zeros;
      Exec Sql
                   Get Diagnostics Condition 1
                   :Text = MESSAGE_TEXT;
      SND-MSG 'Error: ' + Text %target(*caller : 1);
    EndIf;

    Exec Sql
                Close Csr01;
    Leave;
  EndIf;

  SND-MSG jsonData.connectUrl %target(*caller : 1);
Enddo;

// ================ Exit
*Inlr = *On;
Return;
// ==================================================================================
