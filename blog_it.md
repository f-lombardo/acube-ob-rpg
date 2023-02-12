# Come usare API esterne su IBM i: l'esempio Open Banking
La piattaforma IBM i, essendo un server aziendale robusto e versatile, può con facilità collegarsi al mondo delle API REST, 
arricchendo gli applicativi che ospita di funzionalità prese dal cloud.
Nell'esempio di oggi vedremo come leggere i dati dei conti correnti bancari, che la normativa europea PDS2 ha reso fruibili 
anche da terze parti, software gestionali inclusi.
Per fare ciò ci serviremo dei seguenti strumenti:
* Le funzioni SQL [HttpPostClob](https://www.ibm.com/docs/en/i/7.3?topic=overview-httppostblob-httppostclob-scalar-functions) 
e [HttpGetCLob](https://www.ibm.com/docs/en/i/7.3?topic=overview-httpgetblob-httpgetclob-scalar-functions), che consentono di 
effettuare delle chiamate HTTP POST e GET tramite normali statement SQL. (Roberto De Pedrini ne ha parlato [qui](https://blog.faq400.com/it/database-db2-for-i/qsys2-http-functions-it/)).
* La funzione SQL [Json_Table](https://www.ibm.com/docs/en/i/7.3?topic=data-using-json-table) che converte un documento JSON in una tabella di DB2 for i.
* Ovviamente il linguaggio RPG ILE nel moderno formato free.
    
## Ottenere un token JWT con una POST
Le API REST sono, per definizione, stateless, cioè lo stato della comunicazione tra client e server non viene memorizzato sul server tra le varie richieste.
Ogni richiesta appare quindi "nuova" al server e deve pertanto contenere le informazioni necessarie all'autenticazione del client. 
Una delle tecniche spesso utilizzate a questo scopo consiste nell'inviare la coppia utente/password in una prima chiamata di autenticazione, 
che restituisce un token firmato dal server (JSON Web Token o [JWT](https://jwt.io/introduction)) con scadenza temporale, nel quale si certifica l'identità del proprietario. 
Il token viene quindi trasmesso in tutte le chiamate successive (fino alla sua scadenza) senza la necessità di presentare nuovamente le credenziali.
Anche il servizio di [A-CUBE per l'interazione con i conti correnti](https://docs.acubeapi.com/documentation/open-banking), 
per il quale è possibile richiedere delle credenziali di prova, prevede l'[autenticazione tramite JWT](https://docs.acubeapi.com/documentation/common/authentication/).
Vediamo il [programma d'esempio che effettua la connessione](getjwt.rpgle). 

A fronte di questa risposta JSON restituita dalla POST di login: 
```json
{ "token": "a very long encrypted token" }
```
definiamo una ds utile ad estrarne il campo `token`
```rpgle
dcl-ds jsonData   qualified;
  token      varchar(2048);
end-ds;
```

Componiamo quindi le variabili che ci saranno utili per effettuare la chiamata, prendendo utente e password da variabili d'ambiente:
```rpgle
WebServiceUrl = 'https://common-sandbox.api.acubeapi.com/' +
                  'login';

WebServiceHeader = '<httpHeader>-
                       <header name="content-type" value="application/json" />-
                     </httpHeader>';

Email = %str(getenv('ACUBE_EMAIL'));
Password = %str(getenv('ACUBE_PASSWORD'));

WebServiceBody   = '{"email": "' + Email + '", "password": "' + Password + '"}';
```
Veniamo ora alla parte più importante. Grazie all'aiuto del linguaggio SQL incapsulato nel nostro programma RPG, possiamo:
1. effettuare una HTTPPOST verso il servizio con la funzione `Systools.HttpPostClob`
```rpgle
Systools.HttpPostClob(:WebServiceUrl, :WebServiceHeader, :WebServiceBody)
``` 
2. trasformare la risposta JSON in una tabella relazionale con la funzione `Json_Table`:
```rpgle
Select * from
   Json_Table(Systools.HttpPostClob(:WebServiceUrl, :WebServiceHeader, :WebServiceBody),
    '$'
    Columns(Token VarChar(2048)  Path '$.token'));
``` 
Le espressioni con il `$` rappresentano il percorso nella struttura JSON da cui partire per estrarre i dati: 
`$` è il punto corrente, `$.nomeCampo` il campo `nomeCampo` contenuto nell'oggetto corrente. [Qui](https://jsonpath.com/) potete fare qualche prova con
questi che sono detti `JSONPath`.

