# Keelemudelitele viipade koostamine
## Õpiväljundid
Kursuse läbinu:
- Koostab efektiivseid viipasid
- Analüüsib keelemudelite vastuseid
- Täiustab viipa iteratiivselt
- Rakendab viipade koostamise parimaid praktikaid

```mermaid
flowchart TB
    subgraph Tegum1[Viipade koostamine]
    t1[TELL: Viiba struktuur ja komponendid]
    t2[SHOW: Näited erinevatest viipadest]
    t3[ASK: Viiba komponentide tuvastamine]
    t4[DO: Lihtsa viiba koostamine]
    t1 --> t2 --> t3 --> t4
    end

    subgraph Tegum2[Vastuste analüüs]
    a1[TELL: Vastuste hindamise kriteeriumid]
    a2[SHOW: Heade ja halbade vastuste näited]
    a3[ASK: Vastuste kvaliteedi hindamine]
    a4[DO: Analüüsi raport koostamine]
    a1 --> a2 --> a3 --> a4
    end

    subgraph Tegum3[Viiba iteratiivne täiustamine]
    i1[TELL: Iteratiivse täiustamise protsess]
    i2[SHOW: Viiba parendamise näited]
    i3[ASK: Parendamisvõimaluste leidmine]
    i4[DO: Viiba optimeerimise projekt]
    i1 --> i2 --> i3 --> i4
    end

    Tegum1 --> Tegum2 --> Tegum3
```
## Harjutused
```mermaid
flowchart TB
    subgraph Harjutused/Ülesanded
    h1[ASK: Viip1 - Baasviip lihtsa ülesande jaoks]
    h2[ASK: Viip2 - Konteksti lisamine viibale]
    h3[DO: Projekt1 - Vastuste kvaliteedi analüüs]
    h4[DO: Projekt2 - Viiba iteratiivne parendamine]
    h5[DO: Projekt3 - Kompleksne viiba koostamine]
    h6[DO: Lõpuprojekt - Reaalse probleemi lahendamine]
    h1 --> h2 --> h3 --> h4 --> h5 --> h6
    end
```

### Selgitused (ASK):

**"Baasviip"** - koostab lihtsa viiba etteantud ülesande põhjal

Raskusaste: **kerge**  
Seotud tegumiga: **Viipade koostamine**


**"Konteksti lisamine"** - täiendab olemasolevat viipa asjakohase kontekstiga

Raskusaste: **keskmine**  
Seotud tegumiga: **Viipade koostamine**

### Ülesanded (DO):

**"Vastuste analüüs"** - analüüsib viie erineva viiba vastuseid, koostab võrdlustabeli

Raskusaste: **keskmine**  
Seotud tegumiga: Vastuste analüüs

**"Iteratiivne parendamine"** - võtab ühe viiba ja täiustab seda vähemalt kolm korda

Raskusaste: **keskmine-raske**  
Seotud tegumiga: Viipade iteratiivne täiustamine


"Kompleksne viipade koostamine" - lahendab keerukama ülesande, mis nõuab mitme viiba kombineerimist

Raskusaste: **raske**  
Seotud tegumiga: **kõik tegumid**


**  "Lõpuprojekt"** - valib reaalse probleemi ja lahendab selle LLM abil

Raskusaste: **väga raske**  
Seotud tegumiga: kõik tegumid