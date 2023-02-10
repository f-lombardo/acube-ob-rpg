**FREE
ctl-opt DftActGrp(*No) option (*srcstmt : *nodebugio : *nounref);
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - *
// In order to compile this program run:
// CRTSQLRPGI OBJ(CONNECT) SRCSTMF('/path/to/your/src/connect.rpgle')
// Before running the program add environment variable with fiscal id
// for connection, for example:
// ADDENVVAR ENVVAR(ACUBE_FISCALID) VALUE('LMBFNC')
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - *

// - - - - - - -
// Workfields
// - - - - - - -

dcl-s WebServiceUrl    varchar(2048) inz;
dcl-s WebServiceHeader varchar(2048) inz;
dcl-s WebServiceBody   varchar(2048) inz;
dcl-s Token            varchar(2048) inz;
dcl-s Text             varchar(2048) inz;
dcl-s FiscalId         varchar(2048) inz;

// - - - - - - -

dcl-ds jsonData   qualified;
  connectUrl   varchar(2048);
end-ds;

// ========================================================================*
// External program calls
// ------------------------------------------------------------------------*
dcl-pr getenv pointer extproc('getenv');
  *n pointer value options(*string:*trim);
end-pr;

dcl-pr writeJobLog int(10) extproc('Qp0zLprintf');
  *n pointer value options(*string); // logMsg
  *n pointer value options(*string:*nopass);
  *n pointer value options(*string:*nopass);
  *n pointer value options(*string:*nopass);
  *n pointer value options(*string:*nopass);
  *n pointer value options(*string:*nopass);
  *n pointer value options(*string:*nopass);
  *n pointer value options(*string:*nopass);
  *n pointer value options(*string:*nopass);
  *n pointer value options(*string:*nopass);
  *n pointer value options(*string:*nopass);
end-pr;

dcl-c JOBLOGCRLF const(x'0d25');
// Example:
//     writeJobLog ( WebServiceHeader + '%s' : JOBLOGCRLF );
// ========================================================================*

Exsr SetUp;
Exsr ConsumeWs;

*Inlr = *On;
Return;

// --------------------------------------------------------
// SetUp  subroutine
// --------------------------------------------------------

Begsr SetUp;
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
Endsr;

// --------------------------------------------------------
// ConsumeWs  subroutine
// --------------------------------------------------------

Begsr ConsumeWs;

  Exec sql
    Declare CsrC01 Cursor For
     Select * from
       Json_Table(Systools.HttpPostClob(:WebServiceUrl, :WebServiceHeader,
                                        :WebServiceBody),
       '$'
       Columns(ConnectUrl VarChar(2048)  Path '$.connectUrl'));

  Exec Sql Close CsrC01;
  Exec Sql Open  CsrC01;

  DoU 1 = 0;
    Exec Sql
         Fetch Next From CsrC01 into :jsonData;

    If SqlCode < *Zeros or SqlCode = 100;

      If SqlCode < *Zeros;
        Exec Sql
                   Get Diagnostics Condition 1
                   :Text = MESSAGE_TEXT;
        writeJobLog(Text + '%s' : JOBLOGCRLF);
      EndIf;

      Exec Sql
                Close CsrC01;
      Leave;
    EndIf;


    writeJobLog ( jsonData.connectUrl + '%s' : JOBLOGCRLF );
  Enddo;

Endsr;

// - - - - - - - - - - - - - - 

