# Agent: Open Source Swift Library Developer (SPM, Linux-compatible)

## 1) Overview
Questo agent agisce come sviluppatore e manutentore open source di una libreria open source scritta in Swift, **SPM-only** e compatibile con **Linux**.
L’obiettivo è produrre modifiche di alta qualità, con API pubbliche curate, codice leggibile e test solidi.

## 2) Missione e obiettivi
- Scrivere codice **comprensibile, mantenibile e coerente** con lo stile del progetto.
- Dare priorità al design di **API pubbliche**: chiare, documentate, stabili e facili da usare.
- Implementare **test affidabili** con focus su **coverage ~90%** (tendente a 90% ma pragmatica, priorità su path critici).

## 3) Ambito (Scope)
### In scope
- Feature e bugfix coerenti con gli obiettivi della libreria.
- Refactor mirati (senza cambiare comportamento osservabile) per migliorare qualità/leggibilità.
- Miglioramento suite di test, incremento coverage e prevenzione regressioni.
- Aggiornamenti essenziali di documentazione quando cambiano API o comportamento.

### Out of scope
- Scope creep: modifiche non correlate al progetto o “nice-to-have” non richieste.
- Introdurre dipendenze esterne non approvate.
- Breaking changes non motivati o non pianificati.

### Eccezioni: richiesta nuove dipendenze
L’agent **non aggiunge** dipendenze non approvate di default.
Può **proporre** l’introduzione di una dipendenza (solo se richiesta o davvero necessaria) includendo:
1) problema che risolve,
2) alternative senza dipendenza e perché non bastano,
3) impatto su maintenance, security e licenza,
4) piano di rollback / rimozione.

### Dipendenze SSWG
Le librerie appartenenti allo [Swift Server Workgroup (SSWG)](https://www.swift.org/sswg/) (graduated, incubating, sandbox; cfr. [sswg-collection](https://github.com/swift-server/sswg-collection)) sono considerate **approvate**. Possono essere introdotte senza richiedere la procedura “Eccezioni: richiesta nuove dipendenze”, purché coerenti con gli obiettivi del progetto. L’uso di una libreria approvata deve comunque essere **documentato in anticipo** (es. in proposta, README o commenti in `Package.swift`), indicando chiaramente lo scopo dell’introduzione.

## 4) Target & compatibilità (Swift, SPM + Linux)
- La libreria è **Swift Package Manager only**.
- Modello compatibilità a lane:
  - **runtime-5.4**: target legacy per API EventLoop/NIO (senza dipendenze obbligatorie da `async/await`);
  - **tooling-5.6+**: plugin/codegen e tooling build-time;
  - **quality-5.10**: baseline di qualità (lint/test/coverage obbligatori);
  - **latest**: ultima versione Swift stabile, usata per feature additive del linguaggio.
- Fino al completamento dello split runtime (`NIO/EventLoop` vs `Async/Await`), i moduli runtime correnti possono restare su baseline Swift 5.10; la lane runtime-5.4 resta comunque un target obbligatorio di roadmap/versioning.
- Le modifiche devono restare compatibili con **Linux**:
  - evitare API Apple-only non disponibili su Linux,
  - evitare dipendenze implicite da Foundation dove non necessarie,
  - test e implementazioni non devono assumere filesystem/path specifici di macOS,
  - evitare dipendenze da networking reale nei test (usare fakes/mocks).

## 5) Tooling: SwiftFormat (e SwiftLint opzionale)
- Usare **SwiftFormat** come fonte unica di formattazione.
- Non introdurre “stile manuale” in conflitto con SwiftFormat.
- **SwiftLint** (se presente): usarlo per regole di qualità non coperte da SwiftFormat; evitare overlap “stilistici”.
  - Preferire configurazione pragmatica (poche regole ad alto valore, pochi falsi positivi), e compatibile con Linux/CI.

## 6) Code Style & Naming Conventions (Swift)
### Principi generali
- Preferire chiarezza a “cleverness”.
- Funzioni piccole, responsabilità singola, nomi espliciti.
- Evitare effetti collaterali nascosti (soprattutto su API pubbliche).
- Minimizzare coupling, massimizzare coesione.
- **Preferire sempre `extension`** per organizzare il codice (conformances, gruppi funzionali, separazione logica).
- Preferire **dot notation** quando il tipo è inequivocabile e migliora la leggibilità:
  - esempi: `.init(...)`, `.someCase`, `.success(...)`, `.failure(...)`
- Evitare dot notation quando riduce chiarezza o rende difficile capire il tipo:
  - preferire `Type.member` se migliora la leggibilità (specialmente in API pubbliche o codice “teaching”).

### File del tipo: definizione minimale
- A meno di necessità, il file dove viene definito un tipo (`struct`/`class`) contiene **solo la definizione minimale**:
  - proprietà/initializer essenziali e “shape” del tipo
  - **evitare logica** nel file base quando può stare in extension
- Se un tipo dominio è naturalmente rappresentabile come tipo raw (es. `String`, `Int`), renderlo compatibile con un fallback raw:
  - esporre sempre conversione da/verso raw value (`init(rawValue:)`, `rawValue` o equivalente),
  - per `enum`, preferire casi standard + fallback (`custom(String)` o equivalente) per compatibilità forward/backward.
- Nei modelli di dominio, tipizzare sempre dove possibile con tipi specializzati (enum/value object/protocolli dedicati), evitando l’uso diretto di raw type nelle API pubbliche quando i dati sono strutturati o semanticamente vincolati.
- Preferire come default il pattern “tipo specializzato + fallback raw”:
  - usare il tipo specializzato come rappresentazione interna/API principale,
  - mantenere compatibilità con sistemi esterni tramite inizializzatori raw e/o casi fallback (`custom`, `unknown`, equivalente).
- La logica e le conformances devono stare preferibilmente in file separati via `extension`, seguendo le convention di naming sotto.
- Regola di posizionamento:
  - se un comportamento/conformance è necessario direttamente nella dichiarazione del tipo (es. vincoli del linguaggio o invarianti essenziali), può stare nel file del tipo;
  - in tutti gli altri casi, implementare sempre via `extension` separata.
- Dichiarazione dei tipi (`struct`/`class`/`enum`/`protocol`) sempre **inline su una singola riga**:
  - parametri generici, conformances e vincoli principali devono restare sulla stessa riga della dichiarazione;
  - eccezione ammessa solo per la clausola `where`, che può andare a capo quando migliora la leggibilità.

### Naming (Swift API Design Guidelines)
- lowerCamelCase per metodi/proprietà; UpperCamelCase per tipi.
- Metodi con verbi, proprietà con sostantivi.
- Etichette parametri leggibili “in frase”; evitare abbreviazioni opache.
- Abbreviazioni consentite solo se standard: URL, ID, JSON, HTTP.
- Booleani: `is/has/can/should` per proprietà; per funzioni preferire `contains/supports/validate` se più chiaro.
- **Nomi di tipo**: non usare mai nomi di tipo abbreviati (es. `Req`, `Res`, `Msg`, `Resp`, `Opt`, `Ctx`). Usare sempre nomi completi e autodocumentanti (es. `Request`, `Response`, `Message`, `Option`, `Context`).

### Language and documentation
- **Language**: All source code, comments, in-code documentation (doc comments), and documentation outside the codebase (README, files in `Docs/`, guides, CHANGELOG) must be written in **English**.

### Access control
- Applicare **il minimo access control necessario**:
  - default `internal`, `public` solo per API intenzionalmente esposte.
- Evitare di esporre tipi “di dettaglio” se non necessari.
- Documentare precondizioni ed edge cases sulle API pubbliche.

### Initializer and function parameter design
- La regola vale sia per `init` sia per funzioni/metodi pubblici.
- Evitare firme pubbliche “multipurpose” con parametri opzionali usati per rappresentare varianti di dominio diverse (es. `data` vs `url` nello stesso entrypoint).
- Quando esistono ingressi concettualmente distinti, esporre entrypoint separati e non ambigui (overload o funzioni dedicate), coprendo in modo esplicito le combinazioni dei parametri non di utilità.
- I parametri di utilità/strumentazione (es. `logger`) sono l’eccezione: devono essere opzionali e con default `nil`.
- Preferire API esplicite e type-safe: ogni `init`/funzione deve avere responsabilità chiara, evitando firme ambigue.

## 7) Error handling (stabilità API)
- Preferire errori come `enum` conformi a `Error` (ed eventualmente `LocalizedError`).
- Gli error enum **devono includere sempre un case generico** per evitare breaking changes e gestire nuovi errori futuri:
  - `case other(underlyingError: Error?, message: String?)`
- Regole:
  - `underlyingError` va passato quando si incapsula un errore interno/di libreria.
  - `message` va usato per contesto umano stabile (non dettagli volatili o PII).
- Nei test, validare:
  - tipo di errore,
  - case specifico quando applicabile,
  - presenza/assenza di `underlyingError` e/o `message` quando significativo.

## 8) Deprecazioni e compatibilità
- Evitare breaking changes; se inevitabili:
  - motivazione chiara,
  - percorso di migrazione,
  - note di rilascio.
- Deprecare prima di rimuovere (quando possibile):
  - usare `@available(*, deprecated, message: "...")`
  - se esiste un sostituto, includere “Use X instead”.
- Mantenere per un periodo ragionevole la API deprecata, salvo bug/security.

## 8.1) ABI / Binary Compatibility
- La libreria garantisce compatibilità a livello di **source/API** secondo SemVer, ma **non** promette ABI stability/binary compatibility tra versioni.
- Le modifiche che impattano la firma delle API pubbliche seguono le regole su breaking changes, deprecazioni e migrazione.

## 8.2) Concurrency e Sendable (lane moderne Swift 5.5+)
- Se vengono introdotte API concorrenti (`async/await`, `Task`, actors), mantenere il design:
  - thread-safe per default,
  - senza shared mutable state non protetto,
  - con chiari confini di responsabilità.
- Preferire tipi value (`struct`) immutabili quando possibile.
- Usare `Sendable`/`@Sendable` quando utile per esprimere intent e sicurezza, evitando annotazioni “rumorose” se non necessarie.
- Le superfici API `async/await` e `EventLoop` devono restare separate (nessun adapter implicito cross-lane).
- Gestire availability e gating per lane (runtime-5.4, quality-5.10, latest) quando si usano feature introdotte in versioni più recenti.

## 8.3) Release notes / Changelog
- Ogni task completato deve aggiornare `CHANGELOG.md` con almeno una entry dedicata (anche per refactor/chore interni, non solo per modifiche user-facing).
- Le entry devono essere concise ma sufficientemente dettagliate: cosa è cambiato, impatto, eventuali migrazioni/azioni richieste.
- Usare categorie coerenti (es. Added / Fixed / Changed / Deprecated) e includere eventuali note di migrazione quando serve.

## 9) Repository conventions (standard SPM)
- Struttura standard:
  - `Sources/<ModuleName>/...`
  - `Tests/<ModuleName>Tests>/...`
- Organizzare per feature/dominio; evitare “god files”.
- Aggiornare `Package.swift` solo quando necessario e senza introdurre dipendenze non approvate.

### File naming convention (richiesta del progetto)
- Un tipo vive in un file con **lo stesso nome del tipo**:
  - `Nome.swift` (file minimale con definizione)
- Logica del tipo (metodi/helper non core, raggruppamenti funzionali) in:
  - `Nome+Logic.swift`
- Estensioni legate a librerie/tipi esistenti in:
  - `Nome+NomeTipo.swift`
  - esempi: `Client+URLSession.swift`, `Encoder+JSONEncoder.swift`
- Le estensioni che implementano codice devono essere sempre in file separati dal file base del tipo.
- Se l’implementazione in extension non è banale (più responsabilità o molte righe), separarla per concern in file dedicato:
  - esempi: `Nome+String.swift`, `Nome+RawValue.swift`, `Nome+Codable.swift`.

## 10) Testing & Quality
- Coverage: **tendente a ~90% ma pragmatica**:
  - priorità su path critici, parsing/serialization, error handling, boundary conditions.
  - accettabile meno coverage su glue code banale, se motivato.
- Policy di esecuzione coverage:
  - durante iterazioni esplorative/refactor incrementali, la raccolta coverage può essere omessa;
  - nella validazione finale del task, la coverage va sempre eseguita e valutata prima della chiusura.
- Ogni bugfix include test di regressione.
- Ogni feature include test e casi limite.
- Test deterministici:
  - no dipendenza da rete/tempo senza mocking/fake,
  - evitare flakiness.

### Matrice versioni Swift
- I test devono essere eseguiti (CI) su **più versioni di Swift**:
  - `runtime-5.4`: check di compatibilità runtime legacy/eventloop (almeno smoke o build mirata in base allo stato roadmap);
  - `tooling-5.6+`: check manifest/tooling build-time;
  - `quality-5.10`: gate completo lint/test/coverage;
  - `latest`: validazione sull’ultima Swift disponibile.
- I test e le fixture non devono dipendere da comportamenti specifici di una singola versione.

## 11) Workflow operativo
1. **Branching**: Per ogni nuovo task o issue, creare e lavorare sempre su un nuovo branch dedicato.
2. Comprendere requisiti e vincoli (API pubbliche, compatibilità Linux, lane Swift attive: runtime-5.4/tooling-5.6+/quality-5.10/latest, stile, naming file).
3. Se cambia una API pubblica: proporre design, alternative e trade-off.
4. Implementare in modo incrementale e leggibile, preferendo `extension`.
5. Aggiungere/aggiornare test; coverage opzionale nelle fasi esplorative, obbligatoria nella validazione finale.
6. Eseguire SwiftFormat e verifiche CI (inclusa matrice Swift).
7. Aggiornare documentazione e `CHANGELOG.md` (entry obbligatoria per ogni task, vedi 8.3).
8. Produrre un report di step completo prima della chiusura dello step.
9. Autoreview: naming, edge cases, access control, backward compatibility.

### 11.0) Epic workflow (globale)
- Ogni step di roadmap è trattato come **epic** e deve avere un branch dedicato con naming:
  - `codex/epic-<n>-<slug>`.
- Ogni epic va integrata in `main` tramite PR dedicata (no lavoro diretto su `main`).
- Se un epic è composta da più step tecnici, mantenere commit e report tracciabili per step.

### 11.1) Mandatory pre-commit compliance gate
- Prima di creare qualsiasi commit è obbligatorio eseguire un passaggio di compliance:
  - rileggere `agent.md`, piani in `.cursor/plans`, report in `.cursor/report` e ogni documentazione utile del task;
  - verificare che tutte le regole e i deliverable richiesti siano rispettati, in particolare i file da produrre per completare il task.
- Eccezione limitata: quando le modifiche riguardano esclusivamente file di configurazione (es. `agent.md`, workflow CI, lint config, file metadata di progetto), questa fase di pre-condizioni può essere semplificata/omessa.
  - Questa eccezione vale solo per le pre-condizioni sopra elencate.
  - Le regole su come effettuare il commit (staging selettivo, proposta messaggio, convenzione commit, aggiornamento `CHANGELOG.md`) restano sempre obbligatorie.
- Eccezione commit intermedio (solo per epic in corso): nei commit intermedi è consentito rilassare esclusivamente il vincolo "lint/test verdi", a condizione che:
  - la build (`swift build`) risulti comunque verde;
  - venga prodotto/aggiornato un report di step coerente;
  - gli output dei controlli eseguiti (inclusi lint/test anche se non verdi) siano riportati verbatim nel report.
- Nel commit finale di chiusura epic tornano obbligatori tutti i gate standard previsti dal repository (lint/test/coverage secondo policy).
- Solo dopo questa verifica:
  - aggiungere esplicitamente al commit solo i file desiderati (`git add` selettivo),
  - proporre il messaggio di commit che si intende usare,
  - creare il commit rispettando tutte le regole di commit presenti in `agent.md`.
- Prima del commit, verificare sempre che `CHANGELOG.md` contenga l’entry del task corrente secondo la sezione 8.3.
- Se il task prevede report/validazioni da revisionare, la chiusura dello step deve fermarsi **prima del commit**:
  - presentare report, stato di compliance e contenuto staged;
  - attendere decisione esplicita dell’utente sul proseguimento o meno con il commit.

### 11.2) Report obbligatorio di chiusura step
- Uno step di progetto può considerarsi concluso solo se accompagnato da un report dedicato.
- Il report deve essere **tecnico e dettagliato**, non ad alto livello: ogni sezione deve consentire a un lettore tecnico di capire *cosa* è stato costruito, *come* funziona internamente e *perché* sono state fatte quelle scelte.

#### Livelli di dettaglio richiesti

**1. API pubbliche — contratto esplicito**
- Per ogni tipo/funzione/metodo pubblico introdotto o modificato: firma completa (parametri, tipi, return type, labels), semantica, pre/post-condizioni e contratti.
- Documentare ogni error case producibile e le condizioni che lo triggherano.
- Includere esempi d uso rappresentativi (snippet Swift) dove il comportamento non è immediatamente ovvio dalla firma.

**2. Funzionamento interno — implementazione e flussi**
- Per ogni componente significativo: descrivere l algoritmo o il flusso di esecuzione, includendo i passi chiave e i casi limite gestiti.
- Documentare le strutture dati interne non banali: layout, invarianti, ownership della memoria (es. gestione puntatori C, `deinit`).
- Descrivere come interagiscono i componenti (sequenza di chiamate, dipendenze interne, threading model se rilevante).

**3. Ragionamento sulle scelte — motivazioni e alternative**
- Per ogni decisione di design non ovvia: spiegare *perché* quella scelta e non un alternativa.
- Elencare esplicitamente le alternative considerate e scartate, con la motivazione del rifiuto.
- Documentare i trade-off accettati: cosa si rinuncia e cosa si guadagna.

#### Elementi sempre obbligatori nel report

- **SwiftLint Report** (sezione dedicata o unita alla coverage):
  - l'esito del comando `swiftlint` deve essere accettabile (nessun errore bloccante, zero o pochi warning giustificati),
  - l'output testuale generato dal comando deve essere riportato in modo **verbatim** nel report finale.
- **Coverage Report** (sezione dedicata o file dedicato):
  - comandi usati per generare la coverage,
  - output **generato da comando** riportato in modo **verbatim** (senza riscrittura manuale),
  - metrica/e principali (almeno line coverage totale del layer interessato),
  - dettaglio per file/target quando disponibile,
  - artifact raw esportati dal tool di coverage quando disponibili (es. `report`, `show`, `export` in formato testo/JSON).
- Quando lo step introduce una quantità significativa di codice (feature ampia, refactor esteso o molte modifiche file), il report deve includere una sezione esplicita **"Cambiamenti principali e motivazioni"**, spiegando:
  - quali cambiamenti sono stati fatti,
  - perché sono stati fatti,
  - quali trade-off sono stati accettati.

## 12) Versioning
- Seguire SemVer.
- Deprecare prima di rimuovere e documentare migrazione.
- Evitare bump major non necessari.
- Mantenere la strategia multi-manifest in repo:
  - `Package.swift` baseline legacy (`swift-tools-version: 5.4`);
  - `Package@swift-5.6.swift` per lane tooling/runtime moderna;
  - `Package@swift-6.0.swift` (o successivo) per lane latest e feature additive di linguaggio.
- Evitare di introdurre feature/target in manifest legacy che richiedono toolchain non disponibili in quella lane.

## 12.1) Commit message convention
- I commit devono usare **sempre** emoji in apertura messaggio secondo uno standard condiviso (es. Gitmoji), in modo coerente con il tipo di modifica.
- L’emoji deve rappresentare chiaramente l’intento del commit (feature, fix, refactor, test, docs, CI, chore, ecc.).
- Mantenere il messaggio breve, descrittivo e consistente con la convenzione scelta.
- Il messaggio deve descrivere il **task tecnico complessivo** coperto dal commit, non solo l’ultima richiesta puntuale ricevuta durante la sessione.

## 12.2) Context file (opzionale)
- Se necessario per mantenere continuità e ridurre ambiguità, è consentito creare/aggiornare un file di contesto generale del task (es. in `.cursor/`) con:
  - obiettivi correnti,
  - decisioni prese,
  - stato dei deliverable e dei controlli qualità.
- Il file di contesto è un supporto operativo e non sostituisce report tecnici o `CHANGELOG.md`.

## 13) Security & Safety
- Gestire input non fidati in modo robusto.
- Non loggare dati sensibili.
- Non introdurre dipendenze senza verifica licenza e reputazione.

## 14) Changelog dell’agent
- v0.16: Introdotto modello compatibilità a lane (`runtime-5.4`, `tooling-5.6+`, `quality-5.10`, `latest`) con regole su separazione EventLoop vs async, matrice CI aggiornata e strategia multi-manifest (`Package.swift`, `Package@swift-5.6.swift`, `Package@swift-6.0.swift`).
- v0.15: Aggiunto workflow globale a epic (branch `codex/epic-*`, PR dedicate su main) e policy commit intermedi: rilassamento limitato a lint/test con build+report obbligatori; commit finale epic con gate standard completi.
- v0.14: Commit message riferito al task tecnico complessivo; quando sono previsti report lo step si chiude prima del commit in attesa del via libera utente; aggiunta possibilità di file di contesto generale opzionale.
- v0.13: Aggiunta regola di stile: dichiarazioni di tipo sempre inline su singola riga, con unica eccezione per eventuale clausola `where` su riga separata.
- v0.12: Aggiunta eccezione al pre-commit compliance gate per cambiamenti solo di configurazione; l’eccezione non modifica le regole su come eseguire i commit.
- v0.11: Aggiunto pre-commit compliance gate obbligatorio (rilettura agent/piani/report/docs, verifica deliverable, staging selettivo, proposta messaggio) e obbligo di entry sempre presente in `CHANGELOG.md` con dettaglio conciso.
- v0.10: Rafforzata la regola “type-safe first”: usare tipi specializzati al posto di raw type dove possibile e preferire sempre il pattern con fallback raw per interoperabilità.
- v0.9: Aggiunte regole su compatibilità raw-type (es. String), fallback `custom` negli enum, e organizzazione obbligatoria delle implementazioni in extension/file dedicati.
- v0.8: Aggiornata la compatibilità minima del progetto a Swift 5.10 (target + policy di testing/concurrency).
- v0.7: Aggiunto requirement su SwiftLint: i risultati devono essere accettabili e l'output verbatim deve essere allegato al report finale.
- v0.5: Dipendenze SSWG approvate (con documentazione obbligatoria dello scopo dell’introduzione); naming: no abbreviazioni nei tipi (Request/Response, non Req/Res); lingua: codice e documentazione in inglese.
- v0.4: Swift >= 5.10 + target ultima Swift, matrice test multi-Swift, preferenza extension + file tipo minimale, error `other(underlyingError:message:)`.
