**FREE
ctl-opt DftActGrp(*No) option (*srcstmt : *nodebugio : *nounref);
// ==================================================================================
// In order to compile this program run:
// CRTSQLRPGI OBJ(TRANSACTS) SRCSTMF('/path/to/your/src/transacts.rpgle')
// Before running the program add environment variable with fiscal id
// for transactions, for example:
// ADDENVVAR ENVVAR(ACUBE_FISCALID) VALUE('LMBFNC')
// ==================================================================================

// ==================================================================================
// Variables
// ==================================================================================
dcl-s WebServiceUrl    varchar(2048) inz;
dcl-s WebServiceHeader varchar(2048) inz;
dcl-s Token            varchar(2048) inz;
dcl-s Text             varchar(2048) inz;
dcl-s FiscalId         varchar(2048) inz;

// A ds that will contain data from JSON response
dcl-ds jsonData   qualified;
  amount          varchar(64);
  currencyCode    varchar(3);
  description     varchar(2048);
  madeOn          varchar(10);
end-ds;

// Vars for printing
dcl-f qprint printer(132) usage(*output) oflind(overflow);
dcl-ds line len(132) end-ds;

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
               'business-registry/' + FiscalId + '/transactions';

Token = %str(getenv('ACUBE_TOKEN'));

WebServiceHeader = '<httpHeader> ' +
                  '  <header name="authorization" value="bearer ' + Token + '" /> ' +
                  '  <header name="accept" value="application/json" /> ' +
                  '  <header name="content-type" value="application/json" /> ' +
                  '</httpHeader>';

// ================ Consume Web service
Exec sql
    Declare Csr01 Cursor For
     Select * from
       Json_Table(Systools.HttpGetClob(:WebServiceUrl, :WebServiceHeader),
       '$'
       Columns(Amount VarChar(64)  Path '$.amount', Currency  varchar(3) Path '$.currencyCode',
               Description Varchar(2048) Path '$.description', madeOn Varchar(10) Path '$.madeOn'));

Exec Sql Close Csr01;
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

  line = 'Date: ' + jsonData.madeOn + ' Amount: ' + jsonData.currencyCode + ' ' + jsonData.amount;
  write qprint line;
  line = 'Description: ' + jsonData.description;
  write qprint line;
  line = '------------------------------------------------------------------------------';
  write qprint line;
Enddo;

SND-MSG 'Transactions printed successfully' %target(*caller : 1);

// ================ Exit
*Inlr = *On;
Return;
// ==================================================================================
