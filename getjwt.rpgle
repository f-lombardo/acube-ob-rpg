**FREE
ctl-opt DftActGrp(*No) option (*srcstmt : *nodebugio : *nounref);
// ==================================================================================
// In order to compile this program run:
// CRTSQLRPGI OBJ(GETJWT) SRCSTMF('/path/to/your/src/getjwt.rpgle')
// Before running the program add environment variables with your credentials,
// for example:
// ADDENVVAR ENVVAR(ACUBE_EMAIL) VALUE('your@email.test')
// ADDENVVAR ENVVAR(ACUBE_PASSWORD) VALUE('your_password')
// ==================================================================================

// ==================================================================================
// Variables
// ==================================================================================
dcl-s WebServiceUrl    varchar(1024) inz;
dcl-s WebServiceHeader varchar(1024) inz;
dcl-s WebServiceBody   varchar(1024) inz;
dcl-s Text             varchar(2048) inz;
dcl-s Email            varchar(30)   inz;
dcl-s Password         varchar(30)   inz;

// A ds that will contain data from JSON response
dcl-ds jsonData   qualified;
  token      varchar(2048);
end-ds;

// ==================================================================================
// External utilities
// ==================================================================================
dcl-pr getenv pointer extproc('getenv');
  *n pointer value options(*string:*trim);
end-pr;

dcl-pr putenv int(10) extproc('putenv');
  *n pointer value options(*string:*trim) ;
end-pr;

// ==================================================================================
//                             Main program
// ==================================================================================

// ================ SetUp  vars
WebServiceUrl = 'https://common-sandbox.api.acubeapi.com/' +
                  'login';

WebServiceHeader = '<httpHeader>-
                       <header name="content-type" value="application/json" />-
                     </httpHeader>';

Email = %str(getenv('ACUBE_EMAIL'));
Password = %str(getenv('ACUBE_PASSWORD'));

WebServiceBody   = '{"email": "' + Email + '", "password": "' + Password + '"}';

// ================ Consume Web service
Exec sql
   Declare Csr01 Cursor For

     Select * from
       Json_Table(Systools.HttpPostClob(:WebServiceUrl, :WebServiceHeader,
                                        :WebServiceBody),
       '$'
       Columns(Token VarChar(2048)  Path '$.token'));

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

  putenv('ACUBE_TOKEN=' + jsonData.token);
  SND-MSG 'Login OK' %target(*caller : 1);
Enddo;

// ================ Exit
*Inlr = *On;
Return;
// ==================================================================================
