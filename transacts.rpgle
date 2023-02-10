**FREE
ctl-opt DftActGrp(*No) option (*srcstmt : *nodebugio : *nounref);
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - *
// In order to compile this program run:
// CRTSQLRPGI OBJ(TRANSACTS) SRCSTMF('/path/to/your/src/transacts.rpgle')
// Before running the program add environment variable with fiscal id
// for transactions, for example:
// ADDENVVAR ENVVAR(ACUBE_FISCALID) VALUE('LMBFNC')
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - *

// - - - - - - -
// Workfields
// - - - - - - -

dcl-s WebServiceUrl    varchar(2048) inz;
dcl-s WebServiceHeader varchar(2048) inz;
dcl-s Token            varchar(2048) inz;
dcl-s Text             varchar(2048) inz;
dcl-s FiscalId         varchar(2048) inz;

// - - - - - - -

dcl-ds jsonData   qualified;
  amount          varchar(64);
  currencyCode    varchar(3);
  description     varchar(2048);
  madeOn          varchar(10);
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

dcl-f qprint printer(132) usage(*output) oflind(overflow);
dcl-ds line len(132) end-ds;

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
                   'business-registry/' + FiscalId + '/transactions';

  Token = %str(getenv('ACUBE_TOKEN'));

  WebServiceHeader = '<httpHeader> ' +
                      '  <header name="authorization" value="bearer ' + Token + '" /> ' +
                      '  <header name="accept" value="application/json" /> ' +
                      '  <header name="content-type" value="application/json" /> ' +                                              
                      '</httpHeader>';
Endsr;

// --------------------------------------------------------
// ConsumeWs  subroutine
// --------------------------------------------------------

Begsr ConsumeWs;

  Exec sql
    Declare CsrC01 Cursor For
     Select * from
       Json_Table(Systools.HttpGetClob(:WebServiceUrl, :WebServiceHeader),
       '$'
       Columns(Amount VarChar(64)  Path '$.amount', Currency  varchar(3) Path '$.currencyCode',
               Description Varchar(2048) Path '$.description', madeOn Varchar(10) Path '$.madeOn'));

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

    line = 'Date: ' + jsonData.madeOn + ' Amount: ' + jsonData.currencyCode + ' ' + jsonData.amount;
    write qprint line;
    line = 'Description: ' + jsonData.description;
    write qprint line;    
    line = '------------------------------------------------------------------------------';
    write qprint line;    

  Enddo;

Endsr;

// - - - - - - - - - - - - - - 

