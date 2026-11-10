# Dispensa Market Risk e Derivati

Nov 6, 2026 · @Annalisa

## Introduzione

Questa dispensa copre il programma tipico dei colloqui per ruoli di market risk e derivati: per ogni argomento trovi definizione, formule, un esempio numerico e un codice Python. Le fonti sono testi di riferimento, paper originali e documenti regolamentari ufficiali (BCBS, EUR-Lex, BCE), elencati in fondo.

**Come usarla.** Leggi le sezioni nell'ordine: le prime cinque (calcolo stocastico, metodi numerici, derivati, Black-Scholes, greche) sono la base del pricing; dalla sezione sul VaR in poi si passa alla misurazione del rischio e alla regolamentazione.

**Codice.** Tutti gli esempi usano solo `numpy`, `scipy` e `pandas` e sono stati eseguiti: i numeri riportati negli esempi sono l'output reale del codice. Dove in pratica si userebbe una libreria specializzata (QuantLib per le curve, `arch` per i GARCH) lo indico, ma l'implementazione mostrata è "da zero", che è anche ciò che ti chiedono di saper spiegare ai colloqui.

**Convenzioni.** Tassi in capitalizzazione continua salvo diversa indicazione; tempi in anni; VaR ed ES espressi come numeri positivi (perdite); confidenza indicata come α (es. 99%).

## 1. Fondamenti di calcolo stocastico

Il pricing dei derivati si regge su un'idea: sotto la misura risk-neutral Q, il prezzo scontato di ogni titolo negoziato è una martingala, quindi il valore di un derivato è l'attesa scontata del suo payoff. Riferimenti: Shreve vol. II (cap. 3–5), Hull cap. 14–15.

### Moto browniano

Un moto browniano standard W\_t è un processo con W\_0 = 0, incrementi indipendenti, incrementi gaussiani W\_t − W\_s \~ N(0, t − s) e traiettorie continue. Proprietà chiave per i calcoli: (dW)² = dt, dW·dt = 0, (dt)² = 0.

### Lemma di Itô

Se X\_t segue dX = a dt + b dW e f(t, X) è due volte derivabile, allora:

```latex
df = \left( \frac{\partial f}{\partial t} + a\,\frac{\partial f}{\partial x} + \tfrac{1}{2} b^2 \frac{\partial^2 f}{\partial x^2} \right) dt + b\,\frac{\partial f}{\partial x}\, dW
```

Il termine ½ b² f'' è la differenza rispetto al calcolo ordinario e nasce da (dW)² = dt.

**Applicazione classica.** Il prezzo azionario segue un moto browniano geometrico dS = μS dt + σS dW. Con f = ln S si ha f' = 1/S e f'' = −1/S², quindi:

```latex
d\ln S = \left(\mu - \tfrac{1}{2}\sigma^2\right) dt + \sigma\, dW \quad\Longrightarrow\quad S_T = S_0 \exp\!\left[\left(\mu - \tfrac{1}{2}\sigma^2\right)T + \sigma W_T\right]
```

S\_T è lognormale: E\[S\_T\] = S\_0 e^(μT), mentre la mediana è S\_0 e^((μ − σ²/2)T). La correzione −σ²/2 è una domanda frequente ai colloqui.

### Martingale, misura risk-neutral e numerario

Un processo M\_t è una martingala se E\[M\_T | F\_t\] = M\_t: la miglior previsione del valore futuro è il valore di oggi. Il teorema di Girsanov permette di cambiare misura spostando il drift: con dW^Q = dW^P + λ dt, dove λ = (μ − r)/σ è il prezzo di mercato del rischio, sotto Q il sottostante cresce al tasso r.

```latex
V_0 = \mathbb{E}^{Q}\!\left[e^{-rT}\,\text{payoff}(S_T)\right]
```

Più in generale, scelto un numerario N (un titolo con prezzo sempre positivo), esiste una misura in cui V\_t / N\_t è martingala. Con il conto corrente B\_t = e^(rt) si ottiene la misura risk-neutral; con lo zero-coupon P(t, T) si ottiene la misura T-forward, sotto cui il tasso forward è martingala. È la base dei modelli di tasso (sezione 8).

### Esempio numerico

Dati: S\_0 = 100, μ = 8%, σ = 20%, r = 3%, T = 1 anno, 200.000 scenari.

| Grandezza | Formula | Teorico | Simulato |
| --- | --- | --- | --- |
| E\[S\_T\] sotto P | S\_0 e^(μT) | 108,33 | 108,33 |
| Mediana di S\_T | S\_0 e^((μ − σ²/2)T) | 106,18 | 106,12 |
| E\_Q\[e^(−rT) S\_T\] | deve valere S\_0 | 100,00 | 100,00 |

L'ultima riga verifica la martingalità: sotto Q il prezzo scontato in media resta S\_0, qualunque sia μ.

### Codice Python

```python
import numpy as np

# Moto browniano geometrico: dS = mu S dt + sigma S dW
S0, mu, sigma, T, r = 100.0, 0.08, 0.20, 1.0, 0.03
n_paths, n_steps = 200_000, 252
dt = T / n_steps
rng = np.random.default_rng(42)

# Soluzione esatta via Itô: S_T = S0 * exp((mu - sigma^2/2) T + sigma W_T)
Z = rng.standard_normal(n_paths)
ST_P = S0 * np.exp((mu - 0.5 * sigma**2) * T + sigma * np.sqrt(T) * Z)
print(f"E[S_T] teorico  = {S0*np.exp(mu*T):.2f}  | simulato = {ST_P.mean():.2f}")
print(f"Mediana teorica = {S0*np.exp((mu-0.5*sigma**2)*T):.2f}  | simulata = {np.median(ST_P):.2f}")

# Discretizzazione di Eulero del log-prezzo (passi giornalieri)
logS = np.full(20_000, np.log(S0))
for _ in range(n_steps):
    logS += (mu - 0.5*sigma**2)*dt + sigma*np.sqrt(dt)*rng.standard_normal(20_000)
print(f"Eulero su log S: media S_T = {np.exp(logS).mean():.2f}")

# Misura risk-neutral: drift r al posto di mu -> il prezzo scontato è una martingala
ST_Q = S0 * np.exp((r - 0.5 * sigma**2) * T + sigma * np.sqrt(T) * Z)
print(f"E_Q[e^(-rT) S_T] = {np.exp(-r*T)*ST_Q.mean():.2f}  (deve essere ~ S0 = {S0})")
```

## 2. Metodi numerici

Quando un derivato non ha formula chiusa si usa uno di tre metodi: Monte Carlo (payoff dipendenti dal percorso, molti sottostanti), alberi (opzioni americane, intuizione), differenze finite (risolvere la PDE, greche stabili). Sulla stessa call europea tutti e tre convergono al prezzo di Black-Scholes, 9,41. Riferimenti: Hull cap. 13 e 21; Glasserman per il Monte Carlo.

### Monte Carlo

Si simulano N valori di S\_T sotto Q, si calcola il payoff scontato e se ne fa la media. L'errore standard decresce come 1/√N: per dimezzarlo servono quattro volte gli scenari.

```latex
\hat V = e^{-rT}\frac{1}{N}\sum_{i=1}^{N} \max(S_T^{(i)} - K, 0), \qquad \text{IC}_{95\%} = \hat V \pm 1{,}96\,\frac{\hat s}{\sqrt N}
```

Tecniche di riduzione della varianza da conoscere: variabili antitetiche (usare Z e −Z), variabili di controllo (per esempio il sottostante stesso, di cui si conosce l'attesa), importance sampling per le code.

### Albero binomiale (Cox-Ross-Rubinstein)

In ogni passo dt il prezzo sale di u o scende di d, con probabilità risk-neutral p. Si parte dai payoff a scadenza e si torna indietro scontando l'attesa; per un'americana in ogni nodo si prende il massimo tra valore di continuazione ed esercizio immediato.

```latex
u = e^{\sigma\sqrt{\Delta t}}, \quad d = \frac{1}{u}, \quad p = \frac{e^{r\Delta t} - d}{u - d}, \quad V_{i,j} = e^{-r\Delta t}\left[p\,V_{i+1,j+1} + (1-p)\,V_{i+1,j}\right]
```

### Differenze finite

Si discretizza la PDE di Black-Scholes su una griglia (S, t) e si risolve all'indietro dalla scadenza. Lo schema esplicito è semplice ma stabile solo con dt piccolo; Crank-Nicolson (media tra esplicito e implicito) è stabile e accurato al secondo ordine, ed è lo standard.

```latex
\frac{\partial V}{\partial t} + \tfrac{1}{2}\sigma^2 S^2 \frac{\partial^2 V}{\partial S^2} + rS\frac{\partial V}{\partial S} - rV = 0
```

### Esempio numerico

Call europea con S\_0 = 100, K = 100, r = 3%, σ = 20%, T = 1.

| Metodo | Impostazione | Prezzo |
| --- | --- | --- |
| Black-Scholes (formula chiusa) | — | 9,4134 |
| Monte Carlo | 200.000 scenari antitetici | 9,3748 ± 0,0460 |
| Albero CRR | 500 passi | 9,4094 |
| Crank-Nicolson | griglia 300 × 300 | 9,4110 |
| Put europea (albero) | 500 passi | 6,4540 |
| Put americana (albero) | 500 passi | 6,7411 |

La differenza di 0,29 tra put americana ed europea è il valore dell'esercizio anticipato. Per una call americana su un titolo senza dividendi questo valore è zero: l'esercizio anticipato non conviene mai.

### Codice Python

```python
import numpy as np
from scipy.stats import norm
from scipy.linalg import solve_banded

S0, K, r, sigma, T = 100.0, 100.0, 0.03, 0.20, 1.0

def bs_call(S, K, r, sigma, T):
    d1 = (np.log(S/K) + (r + 0.5*sigma**2)*T) / (sigma*np.sqrt(T))
    d2 = d1 - sigma*np.sqrt(T)
    return S*norm.cdf(d1) - K*np.exp(-r*T)*norm.cdf(d2)

# 1) Monte Carlo con variabili antitetiche
def mc_call(S, K, r, sigma, T, n=100_000, seed=1):
    Z = np.random.default_rng(seed).standard_normal(n)
    Z = np.concatenate([Z, -Z])                          # antitetiche
    ST = S*np.exp((r - 0.5*sigma**2)*T + sigma*np.sqrt(T)*Z)
    disc_payoff = np.exp(-r*T)*np.maximum(ST - K, 0)
    pair_mean = 0.5*(disc_payoff[:n] + disc_payoff[n:])  # coppie indipendenti
    return disc_payoff.mean(), 1.96*pair_mean.std(ddof=1)/np.sqrt(n)

# 2) Albero binomiale Cox-Ross-Rubinstein (europea o americana)
def crr(S, K, r, sigma, T, N=500, kind="call", american=False):
    dt = T/N
    u = np.exp(sigma*np.sqrt(dt)); d = 1/u
    p = (np.exp(r*dt) - d)/(u - d)                       # probabilità risk-neutral
    j = np.arange(N+1)
    ST = S * u**j * d**(N-j)
    V = np.maximum(ST-K, 0) if kind == "call" else np.maximum(K-ST, 0)
    for i in range(N-1, -1, -1):
        V = np.exp(-r*dt)*(p*V[1:] + (1-p)*V[:-1])
        if american:
            Si = S * u**np.arange(i+1) * d**(i - np.arange(i+1))
            ex = (Si-K) if kind == "call" else (K-Si)
            V = np.maximum(V, ex)                         # esercizio anticipato
    return V[0]

# 3) Differenze finite: Crank-Nicolson sull'equazione di Black-Scholes
def cn_call(S, K, r, sigma, T, Smax=300, M=300, N=300):
    dS, dt = Smax/M, T/N
    Sg = np.linspace(0, Smax, M+1)
    V = np.maximum(Sg - K, 0)
    i = np.arange(1, M)
    a = 0.25*dt*(sigma**2*i**2 - r*i)
    b = -0.5*dt*(sigma**2*i**2 + r)
    c = 0.25*dt*(sigma**2*i**2 + r*i)
    ab = np.zeros((3, M-1))                              # matrice tridiagonale implicita
    ab[0, 1:] = -c[:-1]; ab[1] = 1 - b; ab[2, :-1] = -a[1:]
    for n in range(N):
        tau = (n+1)*dt
        rhs = a*V[:-2] + (1 + b)*V[1:-1] + c*V[2:]
        upper_old = Smax - K*np.exp(-r*n*dt)
        upper_new = Smax - K*np.exp(-r*tau)
        rhs[-1] += c[-1]*(upper_old + upper_new)          # bordo S = Smax
        V[1:-1] = solve_banded((1, 1), ab, rhs)
        V[0], V[-1] = 0.0, upper_new
    return np.interp(S, Sg, V)

mc, ci = mc_call(S0, K, r, sigma, T)
print(f"Black-Scholes      : {bs_call(S0, K, r, sigma, T):.4f}")
print(f"Monte Carlo (200k) : {mc:.4f} ± {ci:.4f}")
print(f"Albero CRR N=500   : {crr(S0, K, r, sigma, T):.4f}")
print(f"Crank-Nicolson     : {cn_call(S0, K, r, sigma, T):.4f}")
print(f"Put americana CRR  : {crr(S0, K, r, sigma, T, kind='put', american=True):.4f}")
```

## 3. Derivati lineari: forward, futures, swap

I derivati lineari si prezzano per non arbitraggio, senza modelli di volatilità: basta la curva di sconto. Riferimenti: Hull cap. 2–5 e 7.

### Forward

Un forward obbliga a comprare (long) o vendere (short) il sottostante a T al prezzo K. Il prezzo forward equo azzera il valore iniziale; con dividend yield continuo q:

```latex
F_0 = S_0\, e^{(r-q)T}, \qquad f_t = (F_t - K)\, e^{-r(T-t)}
```

f\_t è il valore a t di un forward long stipulato a K. La logica cash-and-carry: se F\_0 fosse più alto, si comprerebbe il sottostante a debito e lo si venderebbe a termine, ottenendo un profitto certo.

### Futures

Il futures è un forward standardizzato e negoziato in borsa, con regolamento giornaliero dei margini (mark-to-market) tramite controparte centrale. Con tassi deterministici prezzo futures e forward coincidono. Con tassi stocastici correlati al sottostante no: per i futures su tassi serve una convexity adjustment, perché i margini incassati si reinvestono a tassi diversi.

### Interest Rate Swap (IRS)

In un IRS una parte paga un tasso fisso K e riceve un tasso variabile (per esempio Euribor 6M) su un nozionale N. Con una sola curva (approccio pre-2008) la gamba variabile vale N\[P(0, t\_0) − P(0, t\_n)\], quindi:

```latex
S_{par} = \frac{P(0,t_0) - P(0,t_n)}{\sum_{i=1}^{n} \tau_i\, P(0,t_i)}, \qquad V_{payer} = N\,(S_{par} - K)\sum_{i=1}^{n} \tau_i\, P(0,t_i)
```

La somma al denominatore si chiama annuity (o PV01 del fisso). Il DV01 è la variazione di valore per +1 punto base sulla curva: è la misura base del rischio di tasso.

### OIS

Un Overnight Index Swap scambia un fisso contro il tasso overnight (in area euro l'€STR) capitalizzato giornalmente sul periodo. Poiché l'overnight ha rischio di credito e di liquidità minimo, la curva OIS è oggi la curva di sconto standard per i derivati collateralizzati (sezione 7).

```latex
\text{gamba variabile OIS} = N\left[\prod_{d}\left(1 + r_d\,\frac{n_d}{360}\right) - 1\right]
```

### Esempio numerico

**Forward.** S\_0 = 100, r = 3%, q = 1%, T = 1: F\_0 = 100 e^(0,02) = 102,02. Dopo sei mesi S = 105, quindi F\_t = 106,06 e il forward long stipulato a 102,02 vale (106,06 − 102,02) e^(−0,015) = 3,98.

**Swap.** Nozionale 10 milioni, 5 anni, pagamenti annuali, curva zero continua:

| Scadenza (anni) | Zero rate | Discount factor |
| --- | --- | --- |
| 1 | 2,00% | 0,980199 |
| 2 | 2,20% | 0,956954 |
| 3 | 2,40% | 0,930531 |
| 4 | 2,50% | 0,904837 |
| 5 | 2,60% | 0,878095 |

Annuity = 4,6506 e tasso par = (1 − 0,878095) / 4,6506 = 2,6213%. Un payer swap che paga fisso al 2,30% vale 10.000.000 × (2,6213% − 2,30%) × 4,6506 = 149.404 EUR: chi paga fisso sotto il par è in guadagno. Il suo DV01 è +4.704 EUR per punto base, perché un rialzo dei tassi aumenta il valore della gamba ricevuta.

### Codice Python

```python
import numpy as np

# Forward su azione con dividend yield continuo
S0, r, q, T = 100.0, 0.03, 0.01, 1.0
F0 = S0*np.exp((r - q)*T)
t, St = 0.5, 105.0
Ft = St*np.exp((r - q)*(T - t))
print(f"F0 = {F0:.4f} | F_t = {Ft:.4f} | valore long = {(Ft - F0)*np.exp(-r*(T - t)):.4f}")

# Interest Rate Swap 5 anni, pagamenti annuali, curva singola
N = 10_000_000
times = np.array([1, 2, 3, 4, 5], dtype=float)
zero = np.array([0.020, 0.022, 0.024, 0.025, 0.026])   # zero rates continui
P = np.exp(-zero*times)                                # discount factor
tau = np.diff(np.r_[0, times])                         # year fraction
annuity = np.sum(tau*P)
par = (1 - P[-1])/annuity
print(f"Annuity = {annuity:.6f} | tasso swap par = {par*100:.4f}%")

# Valore di un payer swap (paghi fisso 2,30%, ricevi variabile)
K = 0.0230
pv_float = N*(1 - P[-1])
pv_fixed = N*K*annuity
print(f"Valore payer = {pv_float - pv_fixed:,.0f}")

# DV01: variazione di valore per +1bp parallelo sulla curva zero
def payer_value(z):
    Pz = np.exp(-z*times)
    return N*(1 - Pz[-1]) - N*K*np.sum(tau*Pz)
print(f"DV01 = {payer_value(zero + 0.0001) - payer_value(zero):,.0f} EUR")
```

## 4. Opzioni plain vanilla e Black-Scholes

Una call ATM a un anno con S = K = 100, r = 3% e σ = 20% vale 9,41 e la put corrispondente 6,46; la differenza, 2,96, è esattamente S − K e^(−rT), come impone la put-call parity. Riferimenti: Hull cap. 10–11 e 15; paper originale di Black e Scholes (1973).

### Payoff

Una call europea dà a scadenza max(S\_T − K, 0), una put max(K − S\_T, 0). Un'opzione americana si può esercitare in qualsiasi momento fino a T.

### Derivazione (in breve)

1. Si costruisce il portafoglio Π = V − Δ S, cioè l'opzione meno Δ azioni.
2. Con il lemma di Itô si scrive dV; scegliendo Δ = ∂V/∂S il termine in dW scompare e Π diventa privo di rischio.
3. Per non arbitraggio un portafoglio privo di rischio rende r: dΠ = rΠ dt. Da qui segue la PDE di Black-Scholes (sezione 2), in cui μ non compare.
4. Risolvendola con il payoff della call come condizione finale, oppure calcolando E\_Q\[e^(−rT) max(S\_T − K, 0)\], si ottiene la formula.

```latex
C = S_0 e^{-qT} N(d_1) - K e^{-rT} N(d_2), \qquad P = K e^{-rT} N(-d_2) - S_0 e^{-qT} N(-d_1)
```

```latex
d_1 = \frac{\ln(S_0/K) + (r - q + \tfrac{1}{2}\sigma^2)T}{\sigma\sqrt T}, \qquad d_2 = d_1 - \sigma\sqrt T
```

N(d\_2) è la probabilità risk-neutral che la call scada in the money; N(d\_1) è il delta.

### Ipotesi e limiti

| Ipotesi | Nella realtà |
| --- | --- |
| Volatilità costante | La volatilità implicita varia con strike e scadenza (smile, sezione 6) |
| Rendimenti lognormali, traiettorie continue | Code spesse e salti: crash più frequenti del previsto |
| Tasso r costante e noto | Tassi stocastici, rilevanti per scadenze lunghe |
| Ribilanciamento continuo senza costi | Si ribilancia a intervalli discreti e con costi di transazione |
| Nessun rischio di controparte, prestito illimitato | Rischio di controparte (sezione 14), vincoli di funding |

### Put-call parity

Un portafoglio long call e short put con stesso strike e scadenza replica un forward, quindi per non arbitraggio:

```latex
C - P = S_0 e^{-qT} - K e^{-rT}
```

Vale per opzioni europee indipendentemente dal modello. Se nel mercato è violata, c'è un arbitraggio (a meno di costi e vincoli).

### Esempio numerico

S = 100, K = 100, r = 3%, σ = 20%, T = 1, nessun dividendo.

1. d\_1 = \[ln(1) + (0,03 + 0,02) × 1\] / 0,20 = 0,2500; d\_2 = 0,2500 − 0,20 = 0,0500.
2. N(d\_1) = 0,5987; N(d\_2) = 0,5199.
3. C = 100 × 0,5987 − 100 e^(−0,03) × 0,5199 = 9,4134.
4. P = C − S + K e^(−rT) = 9,4134 − 100 + 97,0446 = 6,4580.

### Codice Python

```python
import numpy as np
from scipy.stats import norm

def d1d2(S, K, r, sigma, T, q=0.0):
    d1 = (np.log(S/K) + (r - q + 0.5*sigma**2)*T)/(sigma*np.sqrt(T))
    return d1, d1 - sigma*np.sqrt(T)

def bs_price(S, K, r, sigma, T, kind="call", q=0.0):
    d1, d2 = d1d2(S, K, r, sigma, T, q)
    if kind == "call":
        return S*np.exp(-q*T)*norm.cdf(d1) - K*np.exp(-r*T)*norm.cdf(d2)
    return K*np.exp(-r*T)*norm.cdf(-d2) - S*np.exp(-q*T)*norm.cdf(-d1)

S, K, r, sigma, T = 100.0, 100.0, 0.03, 0.20, 1.0
d1, d2 = d1d2(S, K, r, sigma, T)
c = bs_price(S, K, r, sigma, T, "call")
p = bs_price(S, K, r, sigma, T, "put")
print(f"d1={d1:.4f} d2={d2:.4f} N(d1)={norm.cdf(d1):.4f} N(d2)={norm.cdf(d2):.4f}")
print(f"Call={c:.4f} Put={p:.4f}")
print(f"Put-call parity: C-P={c-p:.4f}  S-K e^-rT={S-K*np.exp(-r*T):.4f}")
```

## 5. Greche e delta hedging

Le greche sono le derivate del prezzo rispetto ai fattori di rischio e sono il linguaggio quotidiano di un desk: per la call ATM dell'esempio il delta è 0,60, il gamma 0,019 e il vega 0,39 per punto di volatilità. Riferimenti: Hull cap. 19.

### Formule (call europea, senza dividendi)

| Greca | Definizione | Call | Put |
| --- | --- | --- | --- |
| Delta | ∂V/∂S | N(d\_1) | N(d\_1) − 1 |
| Gamma | ∂²V/∂S² | φ(d\_1) / (Sσ√T) | uguale alla call |
| Vega | ∂V/∂σ | S φ(d\_1) √T | uguale alla call |
| Theta | ∂V/∂t | −Sφ(d\_1)σ/(2√T) − rKe^(−rT)N(d\_2) | −Sφ(d\_1)σ/(2√T) + rKe^(−rT)N(−d\_2) |
| Rho | ∂V/∂r | KTe^(−rT)N(d\_2) | −KTe^(−rT)N(−d\_2) |

φ è la densità normale standard. Gamma e vega sono uguali per call e put con lo stesso strike, conseguenza della put-call parity.

### Come si comportano

- **Delta**: per la call va da 0 (deep OTM) a 1 (deep ITM); ATM è poco sopra 0,5. Vicino a scadenza diventa quasi uno scalino.
- **Gamma**: massimo ATM; per un'opzione ATM cresce come 1/√T verso scadenza, mentre per OTM e ITM tende a zero. È il motivo per cui le opzioni ATM a breve sono le più difficili da coprire.
- **Vega**: massimo ATM e crescente con la scadenza (∝ √T); le opzioni lunghe sono soprattutto esposte alla volatilità.
- **Theta**: di solito negativo per chi è long; ATM a breve scadenza il decadimento è più rapido.

La relazione da ricordare, che deriva dalla PDE di Black-Scholes per un portafoglio delta-neutrale:

```latex
\Theta + \tfrac{1}{2}\sigma^2 S^2\,\Gamma = r\,\Pi
```

In pratica: chi è long gamma paga theta, chi è short gamma lo incassa.

### Delta hedging

Chi vende una call compra Δ azioni e ribilancia nel tempo. Con ribilanciamento continuo e volatilità realizzata uguale a quella usata nel pricing, il P&L finale è zero. Con ribilanciamento discreto resta un errore che si riduce come 1/√n; se la volatilità realizzata supera quella venduta, chi è short gamma perde circa vega × (σ\_realizzata − σ\_implicita).

### Esempio numerico

**Greche della call e della put** (S = K = 100, r = 3%, σ = 20%, T = 1). Vega per 1 punto di volatilità, theta per giorno di calendario, rho per 1 punto percentuale di tasso.

| Greca | Call | Put |
| --- | --- | --- |
| Delta | 0,5987 | −0,4013 |
| Gamma | 0,0193 | 0,0193 |
| Vega | 0,3867 | 0,3867 |
| Theta (al giorno) | −0,0147 | −0,0068 |
| Rho | 0,5046 | −0,4659 |

**Gamma ATM al ridursi della scadenza:** 0,0193 a 1 anno, 0,0396 a 3 mesi, 0,0689 a 1 mese, 0,1438 a 1 settimana, 0,3166 a 1 giorno. Passando da un anno a un giorno il gamma è 16 volte più grande (√252 ≈ 15,9).

**Delta hedging di una call venduta** a 9,41, 20.000 scenari con drift reale 8%:

| Ribilanciamenti nell'anno | P&L medio | Deviazione standard |
| --- | --- | --- |
| 4 (trimestrale) | −0,04 | 3,25 |
| 12 (mensile) | −0,01 | 1,91 |
| 52 (settimanale) | 0,00 | 0,95 |
| 252 (giornaliero) | 0,00 | 0,44 |
| 252, ma vol realizzata 25% | −1,99 | 1,01 |

Il P&L medio è circa zero qualunque sia il drift: la copertura elimina l'esposizione a μ. Nell'ultima riga la perdita di 1,99 è vicina alla stima vega × Δσ = 38,67 × 0,05 = 1,93.

### Codice Python

```python
import numpy as np
from scipy.stats import norm

S, K, r, sigma, T = 100.0, 100.0, 0.03, 0.20, 1.0

def bs_call(S, K, r, sigma, T):
    d1 = (np.log(S/K) + (r + 0.5*sigma**2)*T)/(sigma*np.sqrt(T))
    return S*norm.cdf(d1) - K*np.exp(-r*T)*norm.cdf(d1 - sigma*np.sqrt(T))

def bs_greeks(S, K, r, sigma, T, kind="call"):
    d1 = (np.log(S/K) + (r + 0.5*sigma**2)*T)/(sigma*np.sqrt(T))
    d2 = d1 - sigma*np.sqrt(T)
    pdf = norm.pdf(d1)
    gamma = pdf/(S*sigma*np.sqrt(T))
    vega = S*pdf*np.sqrt(T)
    if kind == "call":
        delta = norm.cdf(d1)
        theta = -S*pdf*sigma/(2*np.sqrt(T)) - r*K*np.exp(-r*T)*norm.cdf(d2)
        rho = K*T*np.exp(-r*T)*norm.cdf(d2)
    else:
        delta = norm.cdf(d1) - 1
        theta = -S*pdf*sigma/(2*np.sqrt(T)) + r*K*np.exp(-r*T)*norm.cdf(-d2)
        rho = -K*T*np.exp(-r*T)*norm.cdf(-d2)
    # vega per 1 punto di vol, theta al giorno, rho per 1 punto %
    return dict(delta=delta, gamma=gamma, vega=vega/100, theta=theta/365, rho=rho/100)

print(bs_greeks(S, K, r, sigma, T, "call"))
for TT in [1.0, 0.25, 1/12, 1/52, 1/252]:
    print(f"T={TT:.4f}  gamma ATM={bs_greeks(S, K, r, sigma, TT)['gamma']:.4f}")

# Delta hedging di una call venduta
def delta_hedge(n_steps, n_paths=20_000, mu=0.08, sigma_real=0.20, seed=7):
    rng = np.random.default_rng(seed)
    dt = T/n_steps
    Sp = np.full(n_paths, S)
    delta = bs_greeks(S, K, r, sigma, T)["delta"]
    cash = bs_call(S, K, r, sigma, T) - delta*Sp      # incasso premio, compro delta azioni
    for i in range(1, n_steps+1):
        Z = rng.standard_normal(n_paths)
        Sp = Sp*np.exp((mu - 0.5*sigma_real**2)*dt + sigma_real*np.sqrt(dt)*Z)
        cash *= np.exp(r*dt)                           # il conto matura interessi
        if i < n_steps:
            new_delta = bs_greeks(Sp, K, r, sigma, T - i*dt)["delta"]
            cash -= (new_delta - delta)*Sp             # ribilanciamento
            delta = new_delta
    pnl = cash + delta*Sp - np.maximum(Sp - K, 0)
    return pnl.mean(), pnl.std()

for n in [4, 12, 52, 252]:
    print(n, [round(x, 4) for x in delta_hedge(n)])
print("vol realizzata 25%:", [round(x, 4) for x in delta_hedge(252, sigma_real=0.25)])
```

## 6. Volatilità implicita, smile e skew

La volatilità implicita è il σ che, inserito in Black-Scholes, restituisce il prezzo di mercato: una call ATM quotata 10,50 invece di 9,41 implica una volatilità del 22,81%. Il mercato quota le opzioni in volatilità, non in prezzo. Riferimenti: Hull cap. 20; Gatheral, The Volatility Surface.

### Calcolo con Newton-Raphson

Non esiste formula inversa, quindi si risolve numericamente BS(σ) = prezzo di mercato. Poiché la derivata del prezzo rispetto a σ è il vega, Newton-Raphson converge in poche iterazioni:

```latex
\sigma_{n+1} = \sigma_n - \frac{BS(\sigma_n) - C^{mkt}}{\text{Vega}(\sigma_n)}
```

Per opzioni molto OTM il vega è quasi nullo e Newton può divergere: in quel caso si usa la bisezione o il metodo di Brent, più lenti ma robusti.

### Smile e skew

Se Black-Scholes fosse corretto, la volatilità implicita sarebbe la stessa per tutti gli strike. Non lo è:

- **Skew azionario**: le put OTM (strike bassi) hanno volatilità più alta delle call OTM. Riflette la domanda di protezione e il fatto che i crolli sono più frequenti e veloci dei rialzi; è evidente dal crash del 1987.
- **Smile su cambi**: volatilità più alta su entrambe le ali, perché le code spesse sono simmetriche.
- **Struttura a termine**: la volatilità implicita varia anche con la scadenza. Strike × scadenza formano la superficie di volatilità.

Lo smile si spiega con distribuzioni a code più spesse della lognormale. I modelli che lo riproducono sono a volatilità locale (Dupire), stocastica (Heston, SABR, sezione 8) o con salti (Merton). Sui mercati FX e tassi le quotazioni si fanno spesso per delta (25-delta risk reversal e butterfly) anziché per strike.

### Esempio numerico

IV di una call ATM a un anno quotata 10,50 (S = K = 100, r = 3%): partendo da σ\_0 = 20%, Newton converge a 22,8083% in 3 iterazioni.

Skew tipico azionario, prezzi di call a un anno e volatilità implicita ricavata da ciascun prezzo:

| Strike | Moneyness K/S | Prezzo call | Volatilità implicita |
| --- | --- | --- | --- |
| 80 | 0,80 | 23,8880 | 23,73% |
| 90 | 0,90 | 15,8443 | 21,39% |
| 100 | 1,00 | 9,4134 | 20,00% |
| 110 | 1,10 | 5,0292 | 19,32% |
| 120 | 1,20 | 2,5050 | 19,17% |

La volatilità decresce con lo strike: le opzioni sugli strike bassi (put OTM, call ITM) sono più care di quanto direbbe la volatilità ATM.

### Codice Python

```python
import numpy as np
from scipy.stats import norm

def bs_call(S, K, r, sigma, T):
    d1 = (np.log(S/K) + (r + 0.5*sigma**2)*T)/(sigma*np.sqrt(T))
    return S*norm.cdf(d1) - K*np.exp(-r*T)*norm.cdf(d1 - sigma*np.sqrt(T))

def vega(S, K, r, sigma, T):
    d1 = (np.log(S/K) + (r + 0.5*sigma**2)*T)/(sigma*np.sqrt(T))
    return S*norm.pdf(d1)*np.sqrt(T)

def implied_vol(price, S, K, r, T, x0=0.2, tol=1e-10, max_iter=100):
    sig = x0
    for it in range(max_iter):
        diff = bs_call(S, K, r, sig, T) - price
        if abs(diff) < tol:
            return sig, it
        sig -= diff/vega(S, K, r, sig, T)              # passo di Newton-Raphson
    raise RuntimeError("non converge: usare scipy.optimize.brentq")

S, r, T = 100.0, 0.03, 1.0
iv, it = implied_vol(10.50, S, 100.0, r, T)
print(f"IV = {iv*100:.4f}% in {it} iterazioni")

# Skew: prezzi generati con una vol decrescente nello strike, poi IV recuperata
strikes = np.array([80, 90, 100, 110, 120.0])
vol = 0.20 - 0.10*np.log(strikes/S) + 0.30*np.log(strikes/S)**2
for K, v in zip(strikes, vol):
    price = bs_call(S, K, r, v, T)
    print(f"K={K:5.0f}  prezzo={price:7.4f}  IV={implied_vol(price, S, K, r, T)[0]*100:6.2f}%")
```

## 7. Curve dei tassi e framework multi-curva

Dal 2008 non esiste più una sola curva: si sconta con la curva OIS (€STR) e si proiettano i flussi variabili con una curva per ogni tenor Euribor. Nell'esempio sotto il forward Euribor 12M sta 20–25 bp sopra il forward €STR: è il basis spread che il modello a curva singola ignora. Riferimenti: Hull cap. 4 e 7; Ametrano e Bianchetti sul multi-curva; documentazione BCE ed EMMI.

### I due tassi di riferimento in area euro

- **€STR** (euro short-term rate): tasso overnight a cui le banche dell'area euro raccolgono fondi unsecured all'ingrosso. Lo calcola la BCE dai dati della segnalazione statistica sul mercato monetario (MMSR), lo pubblica alle 8:00 di ogni giorno TARGET2 ed esiste dal 2 ottobre 2019, quando ha sostituito l'EONIA ([BCE](https://www.ecb.europa.eu/stats/financial_markets_and_interest_rates/euro_short-term_rate/html/eurostr_overview.en.html)).
- **Euribor** (1W, 1M, 3M, 6M, 12M): tasso unsecured a termine, amministrato da EMMI con metodologia ibrida. Il livello 1 usa transazioni reali da almeno 10 milioni; il livello 2 interpola o usa transazioni su scadenze o date vicine ([EMMI](https://emmi-benchmarks.eu/benchmarks/euribor/methodology)). Incorpora un premio di credito e liquidità per la durata, per questo sta sopra l'€STR.

### Bootstrapping

Si ricava la curva un nodo alla volta dagli strumenti quotati, in ordine di scadenza: depositi o fixing per il breve, FRA e futures per il medio, swap per il lungo. Per uno swap a pagamenti annuali con tasso par S\_n, noti i discount factor precedenti:

```latex
S_n \sum_{i=1}^{n} \tau_i P_i = 1 - P_n \quad\Longrightarrow\quad P_n = \frac{1 - S_n \sum_{i=1}^{n-1}\tau_i P_i}{1 + S_n \tau_n}
```

Tra i nodi serve un'interpolazione: log-lineare sui discount factor o spline sui forward sono le più usate. La scelta conta, perché determina la forma dei forward e quindi le sensitivity.

### Multi-curva

1. Si costruisce la curva di sconto dagli OIS su €STR: è la curva coerente con il collaterale remunerato a €STR.
2. Si costruisce la curva di proiezione Euribor dagli IRS quotati, imponendo che valgano zero scontando con la curva OIS. Per uno swap annuale contro Euribor 12M:

```latex
\sum_{i=1}^{n} \tau_i\, P^{OIS}_i\, F_i = S_n \sum_{i=1}^{n} \tau_i\, P^{OIS}_i \quad\Longrightarrow\quad F_n = \frac{S_n A_n - \sum_{i<n} \tau_i P^{OIS}_i F_i}{\tau_n P^{OIS}_n}
```

Con più tenor (3M, 6M) si costruiscono più curve di proiezione, usando anche i basis swap quotati tra un tenor e l'altro.

### Esempio numerico

Tassi par illustrativi, non di mercato: OIS 1,90 / 1,95 / 2,05 / 2,15 / 2,25% e IRS contro Euribor 12M 2,10 / 2,17 / 2,28 / 2,38 / 2,48% da 1 a 5 anni.

| Scadenza | DF OIS | Zero OIS | Forward Euribor 12M | Basis sul forward OIS |
| --- | --- | --- | --- | --- |
| 1 anno | 0,981354 | 1,88% | 2,10% | 20,0 bp |
| 2 anni | 0,962103 | 1,93% | 2,24% | 24,0 bp |
| 3 anni | 0,940871 | 2,03% | 2,51% | 25,1 bp |
| 4 anni | 0,918245 | 2,13% | 2,69% | 23,0 bp |
| 5 anni | 0,894320 | 2,23% | 2,91% | 23,0 bp |

Un IRS payer a 5 anni al 2,40% su 10 milioni vale 37.575 EUR in multi-curva, pari a N × (2,48% − 2,40%) × annuity OIS. Con la curva singola Euribor vale 36.883 EUR: 692 EUR di differenza su un solo swap, che su un portafoglio di migliaia di contratti diventa materiale.

### Codice Python

```python
import numpy as np

T = np.arange(1, 6, dtype=float)    # scadenze 1..5 anni, pagamenti annuali
tau = np.ones(5)

# Dati ILLUSTRATIVI (tassi par)
ois_par = np.array([1.90, 1.95, 2.05, 2.15, 2.25])/100   # OIS su €STR
irs_par = np.array([2.10, 2.17, 2.28, 2.38, 2.48])/100   # IRS fisso vs Euribor 12M

# 1) Bootstrapping della curva di sconto OIS
P_ois = np.zeros(5)
for n in range(5):
    A_prev = np.sum(tau[:n]*P_ois[:n])
    P_ois[n] = (1 - ois_par[n]*A_prev)/(1 + ois_par[n]*tau[n])
print("DF OIS  :", np.round(P_ois, 6))
print("zero OIS:", np.round(-np.log(P_ois)/T*100, 4))

# 2) Curva di proiezione Euribor 12M con sconto OIS
F = np.zeros(5)
for n in range(5):
    A_n = np.sum(tau[:n+1]*P_ois[:n+1])
    known = np.sum(tau[:n]*P_ois[:n]*F[:n])
    F[n] = (irs_par[n]*A_n - known)/(tau[n]*P_ois[n])
P_proj = np.cumprod(1/(1 + tau*F))                     # pseudo-DF Euribor
fwd_ois = (np.r_[1, P_ois[:-1]]/P_ois - 1)/tau
print("Forward Euribor:", np.round(F*100, 4))
print("Basis (bp)     :", np.round((F - fwd_ois)*1e4, 2))

# 3) IRS 5Y payer al 2.40%: multi-curva vs curva singola
N, K = 10_000_000, 0.0240
v_multi = N*np.sum(tau*P_ois*(F - K))
v_single = N*(1 - P_proj[-1]) - N*K*np.sum(tau*P_proj)
print(f"Multi-curva = {v_multi:,.0f} | Curva singola = {v_single:,.0f}")
```

**In produzione con QuantLib** (schema indicativo; non eseguito qui perché la libreria non è installata in questo ambiente):

```python
import QuantLib as ql

today = ql.Date(6, 11, 2026)
ql.Settings.instance().evaluationDate = today
estr = ql.Estr()
helpers = [ql.OISRateHelper(2, ql.Period(f"{y}Y"), ql.QuoteHandle(ql.SimpleQuote(r/100)), estr)
           for y, r in zip([1, 2, 3, 4, 5], [1.90, 1.95, 2.05, 2.15, 2.25])]
curve = ql.PiecewiseLogCubicDiscount(today, helpers, ql.Actual365Fixed())
print(curve.discount(today + ql.Period("5Y")))
```

## 8. Modelli di tasso: Vasicek, Hull-White, SABR

Vasicek è il modello didattico, Hull-White è lo standard di produzione per prezzare derivati su tassi e simulare esposizioni (XVA), SABR serve a interpolare lo smile di cap, floor e swaption. Riferimenti: Brigo e Mercurio, Interest Rate Models; Hull cap. 31–32; Hagan et al. (2002) per SABR.

### Vasicek

Il tasso a breve segue un processo di Ornstein-Uhlenbeck con ritorno alla media: a è la velocità di ritorno, b il livello di lungo periodo, σ la volatilità.

```latex
dr_t = a\,(b - r_t)\,dt + \sigma\, dW_t
```

Il prezzo dello zero-coupon è in forma chiusa (modello affine):

```latex
P(0,T) = A(T)\,e^{-B(T)\,r_0}, \quad B(T) = \frac{1 - e^{-aT}}{a}, \quad A(T) = \exp\!\left[\frac{(B - T)(a^2 b - \sigma^2/2)}{a^2} - \frac{\sigma^2 B^2}{4a}\right]
```

Limiti: con soli tre parametri non riproduce la curva osservata; r è gaussiano, quindi può diventare negativo (oggi è considerato un pregio più che un difetto).

### Hull-White (one-factor)

È un Vasicek in cui il livello dipende dal tempo, θ(t), scelto per riprodurre esattamente la curva di mercato di oggi. Si scrive r\_t = x\_t + φ(t), con x un OU a media zero:

```latex
dr_t = \left[\theta(t) - a\, r_t\right]dt + \sigma\, dW_t, \qquad \varphi(t) = f(0,t) + \frac{\sigma^2}{2a^2}\left(1 - e^{-at}\right)^2
```

f(0, t) è il forward istantaneo di mercato. a e σ si calibrano su swaption o cap; esistono formule chiuse per opzioni su zero-coupon, e quindi per caplet e (con il trucco di Jamshidian) per swaption europee.

### SABR

Modello a volatilità stocastica sul tasso forward F, usato per lo smile di una singola scadenza:

```latex
dF = \alpha F^{\beta}\, dW_1, \qquad d\alpha = \nu\, \alpha\, dW_2, \qquad dW_1\, dW_2 = \rho\, dt
```

α fissa il livello della volatilità ATM, β (di solito fissato a priori, per esempio 0,5) la dipendenza dal livello del tasso, ρ lo skew, ν la curvatura dello smile. Hagan et al. danno un'approssimazione chiusa della volatilità implicita di Black σ\_B(K, F), implementata nel codice. Con tassi negativi o vicini a zero si usa lo shifted SABR (F + s al posto di F) e si quota in volatilità normale (Bachelier).

### Esempio numerico

**Vasicek** con r\_0 = 2%, a = 0,10, b = 3%, σ = 1%:

| Scadenza | P(0,T) | Zero rate |
| --- | --- | --- |
| 1 anno | 0,979740 | 2,05% |
| 5 anni | 0,896554 | 2,18% |
| 10 anni | 0,795819 | 2,28% |

La curva sale verso b perché r\_0 < b. Il Monte Carlo dà P(0,5) = 0,896614, coerente con la formula; a 5 anni l'8,85% degli scenari ha tasso negativo.

**Hull-White** con a = 0,05 e σ = 1%, calibrato a una curva illustrativa: il Monte Carlo riproduce P(0,5) = 0,887763 contro 0,887512 della curva, a conferma che φ(t) incorpora la curva iniziale.

**SABR** con F = 2,5%, T = 1, α = 0,025, β = 0,5, ρ = −0,30, ν = 0,40:

| Strike | Volatilità di Black |
| --- | --- |
| 1,5% | 23,13% |
| 2,0% | 18,76% |
| 2,5% (ATM) | 15,96% |
| 3,0% | 14,72% |
| 3,5% | 14,66% |

Con ρ negativo lo smile è inclinato verso gli strike bassi; ν rialza le ali.

### Codice Python

```python
import numpy as np

# ---------- Vasicek ----------
def vasicek_zcb(r0, a, b, sigma, T):
    B = (1 - np.exp(-a*T))/a
    A = np.exp((B - T)*(a**2*b - sigma**2/2)/a**2 - sigma**2*B**2/(4*a))
    return A*np.exp(-B*r0)

r0, a, b, sig = 0.02, 0.10, 0.03, 0.01
for T in [1, 5, 10]:
    P = vasicek_zcb(r0, a, b, sig, T)
    print(f"T={T:2d}: P={P:.6f} zero={-np.log(P)/T*100:.4f}%")

# Monte Carlo: discretizzazione esatta dell'OU + trapezi per l'integrale di r
rng = np.random.default_rng(3)
n, steps, T = 50_000, 500, 5.0
dt = T/steps
r = np.full(n, r0); integral = np.zeros(n)
for _ in range(steps):
    r_new = (r*np.exp(-a*dt) + b*(1 - np.exp(-a*dt))
             + sig*np.sqrt((1 - np.exp(-2*a*dt))/(2*a))*rng.standard_normal(n))
    integral += 0.5*(r + r_new)*dt
    r = r_new
print(f"MC P(0,5) = {np.exp(-integral).mean():.6f} | P(r<0) = {(r < 0).mean():.2%}")

# ---------- Hull-White calibrato alla curva iniziale ----------
zero = lambda t: 0.019 + 0.006*(1 - np.exp(-t/3))     # curva illustrativa
P0 = lambda t: np.exp(-zero(t)*t)
f0 = lambda t, h=1e-5: -(np.log(P0(t + h)) - np.log(P0(t - h)))/(2*h)
aH, sH = 0.05, 0.01
phi = lambda t: f0(t) + sH**2/(2*aH**2)*(1 - np.exp(-aH*t))**2
rng = np.random.default_rng(5)
x = np.zeros(n); integral = np.zeros(n); t = 0.0
for _ in range(steps):
    x_new = x*np.exp(-aH*dt) + sH*np.sqrt((1 - np.exp(-2*aH*dt))/(2*aH))*rng.standard_normal(n)
    integral += 0.5*((x + phi(t)) + (x_new + phi(t + dt)))*dt
    x, t = x_new, t + dt
print(f"HW MC P(0,5) = {np.exp(-integral).mean():.6f} | mercato = {P0(5.0):.6f}")

# ---------- SABR: approssimazione di Hagan et al. (2002) ----------
def sabr_vol(F, K, T, alpha, beta, rho, nu):
    corr = lambda FK: ((1-beta)**2/24*alpha**2/FK**(1-beta)
                       + rho*beta*nu*alpha/(4*FK**((1-beta)/2)) + (2 - 3*rho**2)/24*nu**2)
    if np.isclose(F, K):
        return alpha/F**(1-beta)*(1 + corr(F*F)*T)
    logFK, FK = np.log(F/K), F*K
    z = nu/alpha*FK**((1-beta)/2)*logFK
    xz = np.log((np.sqrt(1 - 2*rho*z + z**2) + z - rho)/(1 - rho))
    den = FK**((1-beta)/2)*(1 + (1-beta)**2/24*logFK**2 + (1-beta)**4/1920*logFK**4)
    return alpha/den*z/xz*(1 + corr(FK)*T)

for K in [0.015, 0.020, 0.025, 0.030, 0.035]:
    print(f"K={K:.1%}: vol = {sabr_vol(0.025, K, 1.0, 0.025, 0.5, -0.30, 0.40):.2%}")
```

## 9. Value at Risk

Il VaR al livello α su orizzonte h è la perdita che con probabilità α non verrà superata: su un portafoglio di 1 milione con code spesse, il VaR 99% a un giorno è 21.994 EUR con la simulazione storica e 19.467 EUR con il metodo parametrico normale, che sottostima le code. Riferimenti: Jorion, Value at Risk; Hull, Risk Management and Financial Institutions cap. 12–14.

### Definizione

Con L la perdita (= −P&L), il VaR è un quantile della distribuzione delle perdite:

```latex
\text{VaR}_\alpha(L) = \inf\{\ell : P(L > \ell) \le 1 - \alpha\}
```

### I tre metodi

| Metodo | Come funziona | Pro | Contro |
| --- | --- | --- | --- |
| Storico (HS) | Applica al portafoglio di oggi gli shock osservati negli ultimi N giorni (es. 250 o 500) e prende il quantile empirico | Nessuna ipotesi distributiva; cattura code spesse e correlazioni reali | Dipende dalla finestra; reagisce lentamente ai cambi di regime; pochi punti in coda |
| Parametrico (delta-normale) | Ipotizza rendimenti normali: VaR = z\_α σ\_P √h, con σ\_P² = wᵀΣw | Veloce; scomponibile per fattore | Sottostima le code; inadatto a opzioni (non linearità) |
| Monte Carlo | Simula i fattori da un modello stimato e rivaluta tutto il portafoglio in ogni scenario | Gestisce non linearità e path-dependency | Costoso; il risultato dipende dal modello scelto |

```latex
\text{VaR}^{par}_\alpha = z_\alpha\,\sqrt{w^\top \Sigma\, w}\,\sqrt{h}, \qquad z_{99\%} = 2{,}326
```

La regola della radice del tempo (VaR a 10 giorni = VaR a 1 giorno × √10) vale solo con rendimenti i.i.d. a media nulla; con volatility clustering è un'approssimazione.

**Scomposizione (component VaR).** Nel parametrico il VaR si scompone esattamente per posizione con il teorema di Eulero: CVaR\_i = w\_i × ∂VaR/∂w\_i = z\_α w\_i (Σw)\_i / σ\_P. La somma dei component è il VaR totale; la differenza con la somma dei VaR stand-alone è il beneficio di diversificazione.

### Esempio numerico

Dati sintetici: due asset con volatilità GARCH e shock t di Student (code spesse, curtosi in eccesso del P&L pari a 8). Posizioni 600.000 e 400.000 EUR, ultimi 500 giorni. Volatilità giornaliere 1,12% e 0,77%, correlazione 0,38, σ del portafoglio 8.368 EUR.

| Metodo | VaR 99% 1 giorno | ES 99% 1 giorno | VaR 99% 10 giorni (√10) |
| --- | --- | --- | --- |
| Storico | 21.994 | 26.716 | 69.553 |
| Parametrico normale | 19.467 | 22.303 | 61.561 |
| Monte Carlo normale | 19.216 | 21.991 | 60.766 |

Il Monte Carlo è sotto il parametrico perché rivaluta in modo pieno (exp(r) − 1): su posizioni lunghe la convessità attenua le perdite. Lo storico è il più alto perché i dati hanno code più spesse della normale.

**Component VaR parametrico:** 14.637 EUR il primo asset e 4.830 EUR il secondo, totale 19.467. I VaR stand-alone sono 15.570 e 7.177, totale 22.747: il beneficio di diversificazione è 3.280 EUR.

### Codice Python

Il modulo `data.py` genera i dati sintetici usati anche nelle sezioni 10, 11 e 15.

```python
# data.py
import numpy as np

def simulate_portfolio(n_days=2000, seed=2026):
    """Due asset con volatilità GARCH(1,1) comune e shock t di Student correlati."""
    rng = np.random.default_rng(seed)
    omega, alpha, beta, nu = 2e-6, 0.08, 0.90, 5
    L = np.linalg.cholesky(np.array([[1.0, 0.4], [0.4, 1.0]]))
    scale = np.array([1.2, 0.8])
    var = omega/(1 - alpha - beta)
    rets = np.zeros((n_days, 2)); eps_prev = 0.0
    for t in range(n_days):
        var = omega + alpha*eps_prev**2 + beta*var
        g = rng.standard_normal(2) @ L.T
        z = g/np.sqrt(rng.chisquare(nu)/nu)/np.sqrt(nu/(nu-2))   # t standardizzata
        rets[t] = np.sqrt(var)*scale*z
        eps_prev = np.sqrt(var)*z[0]
    return rets
```

```python
import numpy as np
from scipy.stats import norm
from data import simulate_portfolio

R = simulate_portfolio()
w = np.array([600_000, 400_000])            # posizioni in EUR
window = R[-500:]
pnl = window @ w                            # P&L giornaliero (approssimazione lineare)
alpha = 0.99

# 1) Storico
var_hs = -np.quantile(pnl, 1 - alpha)
es_hs = -pnl[pnl <= -var_hs].mean()

# 2) Parametrico delta-normale (media zero)
Sigma = np.cov(window.T)
sig_p = np.sqrt(w @ Sigma @ w)
var_par = norm.ppf(alpha)*sig_p
es_par = sig_p*norm.pdf(norm.ppf(alpha))/(1 - alpha)

# 3) Monte Carlo con rivalutazione piena
sims = np.random.default_rng(11).multivariate_normal(np.zeros(2), Sigma, size=200_000)
pnl_mc = (np.exp(sims) - 1) @ w
var_mc = -np.quantile(pnl_mc, 1 - alpha)
es_mc = -pnl_mc[pnl_mc <= -var_mc].mean()

for name, v, e in [("Storico", var_hs, es_hs), ("Parametrico", var_par, es_par),
                   ("Monte Carlo", var_mc, es_mc)]:
    print(f"{name:12s} VaR99={v:9,.0f}  ES99={e:9,.0f}  VaR99 10g={v*np.sqrt(10):9,.0f}")

# Component VaR (scomposizione di Eulero)
comp = w*norm.ppf(alpha)*(Sigma @ w)/sig_p
standalone = norm.ppf(alpha)*np.sqrt(np.diag(Sigma))*w
print("Component:", comp.round(), "| stand-alone:", standalone.round())
```

## 10. Expected Shortfall e misure coerenti

L'Expected Shortfall è la perdita media oltre il VaR. A differenza del VaR è una misura coerente: nell'esempio sotto due obbligazioni hanno VaR 95% nullo ciascuna, ma insieme hanno VaR 100, mentre l'ES del portafoglio (103,2) resta sotto la somma degli ES singoli (160). Riferimenti: Artzner, Delbaen, Eber e Heath (1999); McNeil, Frey ed Embrechts cap. 2 e 8.

### Definizione

```latex
\text{ES}_\alpha(L) = \frac{1}{1-\alpha}\int_\alpha^1 \text{VaR}_u(L)\,du \;\;=\;\; \mathbb{E}\left[L \mid L \ge \text{VaR}_\alpha\right] \;\text{(per L continua)}
```

Per L normale con media μ e deviazione σ: ES\_α = μ + σ φ(z\_α)/(1 − α).

### Gli assiomi di coerenza

Una misura di rischio ρ è coerente se rispetta quattro proprietà:

| Assioma | Formula | Significato |
| --- | --- | --- |
| Monotonia | L\_1 ≤ L\_2 ⇒ ρ(L\_1) ≤ ρ(L\_2) | Più perdite, più rischio |
| Subadditività | ρ(L\_1 + L\_2) ≤ ρ(L\_1) + ρ(L\_2) | La diversificazione non aumenta il rischio |
| Omogeneità positiva | ρ(λL) = λρ(L), λ > 0 | Raddoppiare la posizione raddoppia il rischio |
| Invarianza per traslazione | ρ(L + c) = ρ(L) + c | Aggiungere una perdita certa c aumenta il rischio di c |

Il VaR rispetta tutti gli assiomi tranne la subadditività, che fallisce con distribuzioni discrete o a code molto spesse (crediti, opzioni vendute OTM). Con distribuzioni ellittiche, come la normale, è subadditivo. L'ES è sempre coerente e, al contrario del VaR, guarda a quanto si perde nella coda.

**Perché FRTB usa l'ES al 97,5%.** Per una normale ES 97,5% = 2,338σ, praticamente uguale a VaR 99% = 2,326σ: il livello di capitale resta simile, ma la misura diventa sensibile alle code. Il rovescio della medaglia è che l'ES non è elicitabile e si backtesta con più difficoltà; per questo FRTB continua a backtestare il VaR (sezione 11).

### Esempio numerico: il VaR non è subadditivo

Due obbligazioni indipendenti A e B: ciascuna perde 100 con probabilità 4%, altrimenti 0. Livello α = 95%.

1. **Singola.** P(perdita) = 4% < 5%, quindi VaR\_95 = 0. Il 5% peggiore contiene il 4% di perdite da 100 e l'1% di zero: ES\_95 = (4 × 100 + 1 × 0)/5 = 80.
2. **Portafoglio A + B.** P(almeno un default) = 1 − 0,96² = 7,84% > 5%, quindi VaR\_95 = 100. Nel 5% peggiore: 0,16% di perdite da 200 e 4,84% da 100, quindi ES\_95 = (0,16 × 200 + 4,84 × 100)/5 = 103,2.
3. **Confronto.** VaR(A) + VaR(B) = 0 < VaR(A + B) = 100: il VaR penalizza la diversificazione. ES(A) + ES(B) = 160 ≥ ES(A + B) = 103,2: l'ES no.

Sul portafoglio sintetico della sezione 9 (simulazione storica): ES 97,5% = 21.245 EUR contro VaR 99% = 21.994 EUR, valori vicini come previsto.

### Codice Python

```python
import numpy as np

p, loss, alpha = 0.04, 100.0, 0.95

def var_es_discrete(values, probs, alpha):
    order = np.argsort(values)[::-1]                # perdite in ordine decrescente
    v = np.asarray(values, float)[order]
    pr = np.asarray(probs, float)[order]
    tail = 1 - alpha
    var = v[np.argmax(np.cumsum(pr) > tail)]        # min l con P(L > l) <= 1 - alpha
    rem, acc = tail, 0.0                            # ES: media sul peggior (1-alpha)
    for vi, pi in zip(v, pr):
        take = min(pi, rem); acc += take*vi; rem -= take
        if rem <= 1e-15:
            break
    return var, acc/tail

var_A, es_A = var_es_discrete([loss, 0], [p, 1 - p], alpha)
var_AB, es_AB = var_es_discrete([200, 100, 0], [p**2, 2*p*(1 - p), (1 - p)**2], alpha)
print(f"Singola: VaR95 = {var_A:.1f}  ES95 = {es_A:.1f}")
print(f"A+B    : VaR95 = {var_AB:.1f}  ES95 = {es_AB:.2f}")

# Verifica Monte Carlo
rng = np.random.default_rng(0)
L = loss*(rng.random(2_000_000) < p) + loss*(rng.random(2_000_000) < p)
print(f"MC: VaR95 = {np.quantile(L, alpha):.1f}  ES95 = {np.sort(L)[-int(0.05*len(L)):].mean():.2f}")
```

## 11. Backtesting

Il backtesting confronta ogni giorno il VaR con il P&L realizzato e conta le eccezioni (perdita > VaR). Su 1.000 giorni dei dati sintetici, il VaR normale a finestra fissa ha 22 eccezioni contro 10 attese ed è rifiutato dal test di Kupiec (p = 0,001); il VaR EWMA, che segue il volatility clustering, ne ha 15 e passa (p = 0,14). Riferimenti: Kupiec (1995); Christoffersen (1998); Basel Framework MAR32 e MAR99; CRR art. 366.

### Test di Kupiec (proportion of failures)

Con n giorni, x eccezioni e probabilità teorica p = 1 − α, sotto H0 x è binomiale(n, p). Il test del rapporto di verosimiglianza confronta p con la frequenza osservata p̂ = x/n:

```latex
LR_{POF} = -2\ln\!\left[\frac{(1-p)^{n-x}\,p^{x}}{(1-\hat p)^{n-x}\,\hat p^{x}}\right] \sim \chi^2_1
```

Si rifiuta al 5% se LR > 3,84. Il test controlla quante eccezioni ci sono, non quando avvengono.

### Test di Christoffersen (indipendenza e copertura condizionata)

Un buon modello non deve avere eccezioni a grappolo. Con n\_ij = numero di giorni in stato i seguiti da stato j (1 = eccezione), π\_01 = n\_01/(n\_00 + n\_01) e π\_11 = n\_11/(n\_10 + n\_11):

```latex
LR_{ind} = -2\ln\!\left[\frac{(1-\pi)^{n_{00}+n_{10}}\,\pi^{n_{01}+n_{11}}}{(1-\pi_{01})^{n_{00}}\,\pi_{01}^{n_{01}}\,(1-\pi_{11})^{n_{10}}\,\pi_{11}^{n_{11}}}\right] \sim \chi^2_1, \qquad LR_{cc} = LR_{POF} + LR_{ind} \sim \chi^2_2
```

### Semaforo di Basilea

Su 250 osservazioni con VaR al 99%, le eccezioni determinano la zona e la maggiorazione del moltiplicatore di capitale. Le soglie derivano dalla binomiale: P(X ≤ 4) = 89,22%, P(X ≤ 9) = 99,97%.

| Eccezioni (250 giorni) | Zona | Plus factor CRR art. 366 (moltiplicatore 3 + plus) | Moltiplicatore FRTB MAR99 |
| --- | --- | --- | --- |
| 0–4 | Verde | 0,00 | 1,50 |
| 5 | Giallo | 0,40 | 1,70 |
| 6 | Giallo | 0,50 | 1,76 |
| 7 | Giallo | 0,65 | 1,83 |
| 8 | Giallo | 0,75 | 1,88 |
| 9 | Giallo | 0,85 | 1,92 |
| 10 o più | Rosso | 1,00 | 2,00 |

Fonti: [CRR art. 366](https://legislation.gov.uk/eur/2013/575/article/366/data.xht), [Basel Framework MAR99](https://www.bis.org/committees/bcbs/basel-framework/81307/chapter.pdf). In FRTB c'è anche il backtesting per desk: con più di 12 eccezioni al 99% o più di 30 al 97,5% negli ultimi 12 mesi il desk passa al metodo standard ([MAR32](https://www.sif.admin.ch/dam/sif/de/dokumente/basel-3/MAR32.pdf.download.pdf/MAR32.pdf)).

### Esempio numerico

VaR 99% a un giorno ricalcolato ogni giorno su una finestra di 250 giorni; test sugli ultimi 1.000 giorni (10 eccezioni attese).

| Modello | Eccezioni | Kupiec LR (p-value) | Christoffersen LR (p-value) | Copertura condizionata p-value | Ultimi 250 giorni |
| --- | --- | --- | --- | --- | --- |
| Storico 250 giorni | 17 | 4,09 (0,043) | 1,12 (0,290) | 0,074 | 2, verde |
| Normale, vol a 250 giorni | 22 | 10,84 (0,001) | 0,44 (0,505) | 0,004 | 5, giallo (+0,40) |
| Normale EWMA, λ = 0,94 | 15 | 2,19 (0,139) | 0,46 (0,499) | 0,266 | 4, verde |

Lettura: il normale a vol fissa sottostima il rischio sia perché ignora le code spesse sia perché reagisce lentamente alla volatilità. L'EWMA (RiskMetrics) corregge il secondo difetto. Lo storico è al limite del rifiuto al 5%. Nota anche che il semaforo sugli ultimi 250 giorni può dare verde a un modello che su 1.000 giorni fallisce: 250 osservazioni hanno poca potenza statistica.

### Codice Python

```python
import numpy as np
from scipy.stats import norm, chi2, binom
from data import simulate_portfolio

pnl = simulate_portfolio() @ np.array([600_000, 400_000])
alpha, win = 0.99, 250
p = 1 - alpha

def rolling_var(pnl, method, lam=0.94):
    out = np.full(len(pnl), np.nan)
    for t in range(win, len(pnl)):
        hist = pnl[t-win:t]
        if method == "hs":
            out[t] = -np.quantile(hist, p)
        elif method == "normal":
            out[t] = norm.ppf(alpha)*hist.std(ddof=1)
        elif method == "ewma":                          # RiskMetrics
            wts = lam**np.arange(win)[::-1]; wts /= wts.sum()
            out[t] = norm.ppf(alpha)*np.sqrt(np.sum(wts*hist**2))
    return out

def kupiec(x, n, p):
    phat = x/n
    ll0 = (n - x)*np.log(1 - p) + x*np.log(p)
    ll1 = (n - x)*np.log(1 - phat) + (x*np.log(phat) if x > 0 else 0.0)
    lr = -2*(ll0 - ll1)
    return lr, 1 - chi2.cdf(lr, 1)

def christoffersen(hits):
    h0, h1 = hits[:-1], hits[1:]
    n00 = np.sum((h0 == 0) & (h1 == 0)); n01 = np.sum((h0 == 0) & (h1 == 1))
    n10 = np.sum((h0 == 1) & (h1 == 0)); n11 = np.sum((h0 == 1) & (h1 == 1))
    pi01 = n01/(n00 + n01)
    pi11 = n11/(n10 + n11) if (n10 + n11) > 0 else 0.0
    pi = (n01 + n11)/(n00 + n01 + n10 + n11)
    ll = lambda a, k: k*np.log(a) if k > 0 else 0.0     # 0*log(0) = 0
    l0 = ll(1 - pi, n00 + n10) + ll(pi, n01 + n11)
    l1 = ll(1 - pi01, n00) + ll(pi01, n01) + ll(1 - pi11, n10) + ll(pi11, n11)
    lr = -2*(l0 - l1)
    return lr, 1 - chi2.cdf(lr, 1)

def traffic_light(x):
    if x <= 4:
        return "verde", 0.00
    if x >= 10:
        return "rosso", 1.00
    return "giallo", {5: 0.40, 6: 0.50, 7: 0.65, 8: 0.75, 9: 0.85}[x]

test = slice(1000, 2000)
for method in ["hs", "normal", "ewma"]:
    v = rolling_var(pnl, method)
    hits = (-pnl[test] > v[test]).astype(int)
    x, n = hits.sum(), len(hits)
    lr_uc, p_uc = kupiec(x, n, p)
    lr_ind, p_ind = christoffersen(hits)
    p_cc = 1 - chi2.cdf(lr_uc + lr_ind, 2)
    print(f"{method:6s} x={x} | Kupiec p={p_uc:.3f} | indip. p={p_ind:.3f} | cc p={p_cc:.3f} | "
          f"ultimi 250: {traffic_light(hits[-250:].sum())}")

for k in [4, 9]:
    print(f"P(X <= {k}) = {binom.cdf(k, 250, 0.01):.2%}")
```

## 12. Stress test, sensitivity e P&L explain

Sensitivity e P&L explain sono il lavoro quotidiano di un market risk manager: ogni giorno si scompone la variazione di valore del portafoglio nei contributi dei fattori di rischio. L'espansione di Taylor funziona per movimenti piccoli (nell'esempio spiega il 99% della perdita giornaliera), ma su uno stress del −20% ne coglie solo il 60%: per gli stress serve la rivalutazione piena. Riferimenti: Hull, Risk Management cap. 14 e 22; BCBS, Stress testing principles (2018).

### Sensitivity

| Sensitivity | Definizione | Uso tipico |
| --- | --- | --- |
| DV01 / PV01 | Δ valore per +1 bp parallelo sulla curva | Rischio di tasso aggregato |
| Key-rate (bucketed) DV01 | Δ valore per +1 bp su un solo nodo della curva | Rischio di forma della curva; input di FRTB SA |
| CS01 | Δ valore per +1 bp sugli spread di credito | Obbligazioni, CDS, CVA |
| Delta, gamma, vega | Derivate rispetto a sottostante e volatilità | Opzioni |

Nella somma, i key-rate DV01 ricostruiscono il DV01 parallelo. Si calcolano quasi sempre per differenze finite (bump and revalue), che funzionano con qualsiasi pricer.

### P&L explain (attribution)

Si confronta il P&L da rivalutazione piena con quello ricostruito dalle sensitivity:

```latex
\Delta V \approx \Delta\,\delta S + \tfrac{1}{2}\Gamma\,(\delta S)^2 + \nu\,\delta\sigma + \Theta\,\delta t + \text{Vanna}\,\delta S\,\delta\sigma + \ldots
```

La parte non spiegata (unexplained) segnala fattori mancanti, errori di dati o di modello. In FRTB questo controllo è formalizzato nel PLA test tra P&L ipotetico (HPL, rivalutazione con i modelli del front office) e risk-theoretical P&L (RTPL, dal modello di rischio), sezione 13.

### Stress test

- **Storici**: si riapplicano gli shock di crisi reali (2008, debito sovrano 2011, marzo 2020, shock dei tassi 2022).
- **Ipotetici**: scenari costruiti dagli esperti, coerenti tra fattori (per esempio recessione: azioni −30%, spread +200 bp, tassi −100 bp).
- **Reverse stress test**: si parte da una perdita che metterebbe a rischio la banca e si cerca quale scenario plausibile la produce.

Gli stress non hanno una probabilità associata: completano il VaR, non lo sostituiscono.

### Esempio numerico

**P&L explain** su 10.000 call ATM (S = K = 100, σ = 20%, T = 1). In una giornata S passa da 100 a 98, la volatilità da 20% a 22% e passa un giorno.

| Componente | Contributo (EUR) |
| --- | --- |
| Delta | −11.974 |
| Gamma | +387 |
| Vega | +7.733 |
| Theta | −147 |
| Vanna | +39 |
| **Totale spiegato** | **−3.963** |
| P&L da rivalutazione piena | −4.006 |
| Non spiegato | −43 (1,1%) |

**Stress test** sullo stesso portafoglio: con crollo del 20% e volatilità +15 punti la rivalutazione piena dà −38.373 EUR, l'approssimazione delta-gamma-vega solo −23.074. Con rally del 10% e volatilità −5 punti: +52.886 contro +50.204. Gli shock grandi richiedono termini di ordine superiore (volga, vanna, gamma di ordine 3).

**Key-rate DV01** del payer swap a 5 anni della sezione 3: 23, 44, 64, 83 e 4.490 EUR per bp sui nodi da 1 a 5 anni; la somma, 4.704, coincide con il DV01 parallelo. Quasi tutto il rischio sta sul nodo a 5 anni, dove pesa il rimborso implicito del nozionale nella gamba variabile.

### Codice Python

```python
import numpy as np
from scipy.stats import norm

def bs_call(S, K, r, sigma, T):
    d1 = (np.log(S/K) + (r + 0.5*sigma**2)*T)/(sigma*np.sqrt(T))
    return S*norm.cdf(d1) - K*np.exp(-r*T)*norm.cdf(d1 - sigma*np.sqrt(T))

def greeks_fd(S, K, r, sigma, T, hS=0.01, hv=1e-4, ht=1/365):
    """Greche per differenze finite (bump and revalue)."""
    f = lambda s=S, v=sigma, t=T: bs_call(s, K, r, v, t)
    delta = (f(s=S+hS) - f(s=S-hS))/(2*hS)
    gamma = (f(s=S+hS) - 2*f() + f(s=S-hS))/hS**2
    vega = (f(v=sigma+hv) - f(v=sigma-hv))/(2*hv)
    theta = (f(t=T-ht) - f())/ht
    vanna = (f(s=S+hS, v=sigma+hv) - f(s=S+hS, v=sigma-hv)
             - f(s=S-hS, v=sigma+hv) + f(s=S-hS, v=sigma-hv))/(4*hS*hv)
    return delta, gamma, vega, theta, vanna

n_opt = 10_000
S0, K, r, s0, T = 100.0, 100.0, 0.03, 0.20, 1.0
d, g, v, th, va = greeks_fd(S0, K, r, s0, T)

# P&L explain giornaliero
dS, dv, dt = -2.0, 0.02, 1/365
full = n_opt*(bs_call(S0+dS, K, r, s0+dv, T-dt) - bs_call(S0, K, r, s0, T))
parts = {"Delta": d*dS, "Gamma": 0.5*g*dS**2, "Vega": v*dv, "Theta": th*dt, "Vanna": va*dS*dv}
explained = n_opt*sum(parts.values())
print({k: round(n_opt*x) for k, x in parts.items()})
print(f"Full = {full:,.0f} | Spiegato = {explained:,.0f} | Non spiegato = {full - explained:,.0f}")

# Stress test: rivalutazione piena vs delta-gamma-vega
for sS, sv in [(-0.20, 0.15), (0.10, -0.05)]:
    full_s = n_opt*(bs_call(S0*(1+sS), K, r, s0+sv, T) - bs_call(S0, K, r, s0, T))
    approx = n_opt*(d*S0*sS + 0.5*g*(S0*sS)**2 + v*sv)
    print(f"shock S {sS:+.0%}, vol {sv:+.0%}: full = {full_s:,.0f} | approx = {approx:,.0f}")

# Key-rate DV01 del payer swap 5Y
N, K_sw = 10_000_000, 0.0230
times = np.arange(1, 6, dtype=float)
zero = np.array([0.020, 0.022, 0.024, 0.025, 0.026])
def payer(z):
    P = np.exp(-z*times)
    return N*(1 - P[-1]) - N*K_sw*np.sum(P)
krd = [payer(zero + 1e-4*np.eye(5)[i]) - payer(zero) for i in range(5)]
print("Key-rate DV01:", np.round(krd), "| somma:", round(sum(krd)))
```

## 13. Regolamentazione: Basilea III, CRR e FRTB

Nell'Unione europea FRTB si applica dal 1° gennaio 2027: la Commissione ha già usato i due anni di rinvio consentiti dal CRR e, con un atto delegato di giugno 2026, introduce aggiustamenti temporanei fino alla fine del 2029 ([Commissione europea, Q&A del 4 giugno 2026](https://finance.ec.europa.eu/publications/questions-and-answers-banking-package-amending-market-risk-requirements-preserve-international-level_en)). Fino ad allora le banche europee calcolano il requisito per il rischio di mercato con le regole CRR2 (Basilea 2.5). Ai colloqui servono entrambi.

### Il quadro attuale (CRR2, Basilea 2.5)

- **Metodo standard**: requisiti per tipo di rischio (tasso, azionario, cambio, merci) con coefficienti fissi.
- **Modelli interni**: VaR 99% a 10 giorni più stressed VaR calibrato su 12 mesi di stress, ciascuno moltiplicato per un fattore pari almeno a 3 più il plus factor del backtesting (sezione 11), più l'Incremental Risk Charge per default e migrazione.

```latex
K = \max\!\left(\text{VaR}_{t-1},\; m_c\,\overline{\text{VaR}}_{60}\right) + \max\!\left(\text{sVaR}_{t-1},\; m_s\,\overline{\text{sVaR}}_{60}\right) + \text{IRC}
```

### FRTB: le novità principali

Il testo di riferimento è lo standard BCBS di gennaio 2019 ([d457](https://bis.org/bcbs/publ/d457.htm)), oggi nei capitoli MAR del Basel Framework; nell'UE è recepito dal CRR3 (Regolamento (UE) 2024/1623).

1. **Confine trading book / banking book** più rigido, con forti limiti ai trasferimenti tra i due.
2. **Metodo standard (SA)** basato sulle sensitivity, obbligatorio per tutti anche come floor e confronto.
3. **Metodo dei modelli interni (IMA)** approvato desk per desk, con ES 97,5% al posto di VaR e sVaR.
4. **Orizzonti di liquidità** diversi per fattore di rischio, invece dei 10 giorni uguali per tutti.
5. **Test di idoneità**: backtesting per desk e PLA test; i fattori non modellabili (NMRF) hanno un requisito separato.

### Metodo standard (SA)

Il requisito SA è la somma di tre parti:

- **Sensitivities-Based Method (SbM)**: delta, vega e curvature per sette classi di rischio (tassi GIRR, spread non cartolarizzazioni, spread cartolarizzazioni non CTP, spread del portafoglio di correlazione CTP, azioni, merci, cambi). Le sensitivity si pesano con risk weight regolamentari e si aggregano dentro e tra bucket con correlazioni prescritte, sotto tre scenari di correlazione (alto, medio, basso); il requisito è il massimo dei tre.
- **Default Risk Charge (DRC)**: rischio di default improvviso su obbligazioni, azioni e cartolarizzazioni.
- **Residual Risk Add-On (RRAO)**: maggiorazione per payoff esotici o rischi non catturati dalle sensitivity.

```latex
WS_k = RW_k\, s_k, \qquad K_b = \sqrt{\max\!\left(0,\; \sum_k WS_k^2 + \sum_k \sum_{l \ne k} \rho_{kl}\, WS_k\, WS_l\right)}
```

Per il GIRR delta la correlazione tra due scadenze dello stesso bucket è ρ\_kl = max(e^(−θ|T\_k − T\_l|/min(T\_k, T\_l)), 40%) con θ = 3%; i risk weight si dividono per √2 per le valute specificate, tra cui l'euro. Scenario alto: ρ × 1,25 (max 100%); basso: max(2ρ − 100%, 0,75ρ).

### Metodo dei modelli interni (IMA)

ES al 97,5%, orizzonte base 10 giorni, calibrato su un periodo di stress di 12 mesi ([MAR33](https://www.sif.admin.ch/dam/sif/de/dokumente/basel-3/MAR33.pdf.download.pdf/MAR33.pdf)). Ogni fattore di rischio ha un orizzonte di liquidità di 10, 20, 40, 60 o 120 giorni, e l'ES si scala così:

```latex
\text{ES} = \sqrt{\text{ES}_T(P)^2 + \sum_{j \ge 2}\left(\text{ES}_T(P,j)\,\sqrt{\frac{LH_j - LH_{j-1}}{T}}\right)^2}
```

ES\_T(P, j) è l'ES a 10 giorni ottenuto muovendo solo i fattori con orizzonte almeno LH\_j. Il periodo di stress si calibra con un insieme ridotto di fattori, che deve spiegare almeno il 75% dell'ES completo; il risultato si scala per il rapporto ES\_F,C / ES\_R,C (con floor a 1).

- **IMCC** = ρ × ES non vincolato + (1 − ρ) × somma degli ES per classe di rischio, con ρ = 0,5.
- **Requisito** = max(ultimo valore, m\_c × media 60 giorni di IMCC + SES), più DRC; m\_c = 1,5 più l'add-on del backtesting (fino a 0,5).
- **SES**: requisito per i fattori non modellabili (NMRF), cioè fattori senza abbastanza prezzi osservati reali; si calcola con scenari di stress e senza diversificazione.
- **PLA test** su 250 giorni tra HPL e RTPL ([MAR32](https://www.sif.admin.ch/dam/sif/de/dokumente/basel-3/MAR32.pdf.download.pdf/MAR32.pdf)):

| Zona | Correlazione di Spearman | Statistica KS | Conseguenza |
| --- | --- | --- | --- |
| Verde | > 0,80 | < 0,09 | Desk in IMA |
| Ambra | né verde né rossa | né verde né rossa | IMA con maggiorazione di capitale |
| Rossa | < 0,70 | > 0,12 | Desk al metodo standard |

Il desk è verde solo se lo sono entrambe le metriche, rosso se lo è anche una sola.

### Esempio numerico

**ES aggiustato per la liquidità** (valori illustrativi in milioni di EUR): ES a 10 giorni di tutti i fattori 10,0; dei fattori con orizzonte ≥ 20 giorni 6,0; ≥ 40 giorni 4,0; ≥ 60 giorni 2,0; ≥ 120 giorni 1,0.

```latex
\text{ES} = \sqrt{10^2 + (6\sqrt{1})^2 + (4\sqrt{2})^2 + (2\sqrt{2})^2 + (1\sqrt{6})^2} = \sqrt{100 + 36 + 32 + 8 + 6} = 13{,}49
```

Se tutto avesse orizzonte 120 giorni l'ES sarebbe 10 × √12 = 34,64: la granularità degli orizzonti riduce molto il requisito.

**IMCC**: con ES per classe di 8,0 (tassi), 5,0 (azioni) e 3,0 (cambi), IMCC = 0,5 × 13,49 + 0,5 × 16,0 = 14,75. In zona verde (m\_c = 1,5) il requisito, prima di SES e DRC, è 22,12 milioni.

**SbM, GIRR delta su un bucket EUR**: posizione steepener con sensitivity +5.000 EUR/bp sul 2 anni e −4.000 EUR/bp sul 10 anni. Con risk weight illustrativi di 1,3% e 1,1% divisi per √2 (92 e 78 bp; i valori ufficiali sono nella tabella di MAR21), WS = +459.619 e −311.127. La correlazione è max(e^(−0,03 × 8/2), 40%) = 0,887.

| Scenario di correlazione | ρ | K\_b (EUR) |
| --- | --- | --- |
| Alto | 1,000 | 148.492 |
| Medio | 0,887 | 233.218 |
| Basso | 0,774 | 294.502 |

Per una posizione con segni opposti lo scenario peggiore è quello a correlazione bassa, perché la compensazione è minima.

### Codice Python

```python
import numpy as np

# 1) ES aggiustato per la liquidità
T = 10
LH = np.array([10, 20, 40, 60, 120])
ES_j = np.array([10.0, 6.0, 4.0, 2.0, 1.0])     # ES 10gg dei fattori con LH >= LH_j
terms = [ES_j[0]**2] + [(ES_j[j]*np.sqrt((LH[j] - LH[j-1])/T))**2 for j in range(1, 5)]
ES_LA = np.sqrt(sum(terms))
print(f"ES liquidity-adjusted = {ES_LA:.3f}")

# 2) IMCC e requisito
ES_classes = np.array([8.0, 5.0, 3.0])            # tassi, azioni, cambi
IMCC = 0.5*ES_LA + 0.5*ES_classes.sum()
print(f"IMCC = {IMCC:.3f} | requisito (m_c = 1.5) = {1.5*IMCC:.3f}")

# 3) SbM GIRR delta, un bucket EUR
s = np.array([5_000.0, -4_000.0])                 # EUR per bp
tenor = np.array([2.0, 10.0])
RW_bp = np.array([1.3, 1.1])/100*1e4/np.sqrt(2)  # ILLUSTRATIVI: vedi tabella MAR21
WS = RW_bp*s
rho = max(np.exp(-0.03*abs(tenor[0] - tenor[1])/min(tenor)), 0.40)
Kb = lambda r: np.sqrt(max(WS[0]**2 + WS[1]**2 + 2*r*WS[0]*WS[1], 0))
for name, r in [("alto", min(1.25*rho, 1.0)), ("medio", rho), ("basso", max(2*rho - 1, 0.75*rho))]:
    print(f"scenario {name:5s}: rho = {r:.4f}  K_b = {Kb(r):,.0f}")
```

## 14. XVA e CVA

La CVA è il prezzo del rischio di default della controparte: su un IRS a 5 anni da 10 milioni con una controparte che quota CDS a 150 bp vale circa 8.300 EUR, pari a 1,8 bp l'anno sul tasso fisso. È il punto d'incontro tra market risk e credit risk, quindi un ottimo argomento per valorizzare l'esperienza in Credit Risk. Riferimenti: Gregory, The xVA Challenge; Hull, Options cap. 24; Basel Framework MAR50.

### La famiglia XVA

| Aggiustamento | Cosa misura |
| --- | --- |
| CVA (credit) | Perdita attesa per default della controparte quando l'esposizione è positiva |
| DVA (debit) | Simmetrico: guadagno contabile per il proprio default quando l'esposizione è negativa |
| FVA (funding) | Costo di finanziare le esposizioni non collateralizzate |
| ColVA | Effetto delle condizioni del collaterale (tasso di remunerazione, valuta) |
| MVA (margin) | Costo di finanziare l'initial margin |
| KVA (capital) | Costo del capitale regolamentare assorbito dall'operazione per tutta la vita |

### Formula della CVA

Sotto indipendenza tra esposizione e default della controparte (nessun wrong-way risk):

```latex
\text{CVA} = (1 - R)\int_0^T \text{EE}^*(t)\, dPD(t) \;\approx\; (1 - R)\sum_{i=1}^{n} \text{EE}^*(t_i)\left[S(t_{i-1}) - S(t_i)\right]
```

- **EE*(t)*\* = E\[max(V\_t, 0)\] scontata: l'esposizione attesa positiva, da Monte Carlo sui fattori di mercato (tipicamente Hull-White per i tassi).
- **S(t) = e^(−λt)** = probabilità di sopravvivenza, con intensità calibrata sui CDS: λ ≈ s/(1 − R) (credit triangle).
- **R** = recovery rate, convenzionalmente 40% per senior unsecured.

Approssimazione rapida da colloquio: CVA ≈ spread CDS × EPE × durata. Netting, collaterale (CSA) e initial margin riducono l'EE e quindi la CVA; il wrong-way risk (esposizione alta quando la controparte peggiora) la aumenta.

**Profilo di esposizione.** Per un IRS l'EE ha forma a gobba: cresce perché i tassi si allontanano dal livello iniziale, poi cala perché restano meno flussi. Tra due fixing compare un dente di sega, perché la cedola variabile già fissata diventa "vecchia". Per un cross-currency swap con scambio finale di nozionale l'EE invece cresce fino a scadenza.

**Lato regolamentare.** Oltre al valore contabile c'è il requisito di capitale per il rischio CVA: Basilea III finale prevede il metodo base (BA-CVA) e quello standard basato sulle sensitivity (SA-CVA). CCR ed esposizioni sono misurati con SA-CCR o modelli interni (IMM).

### Esempio numerico

IRS payer a 5 anni, 10 milioni, pagamenti annuali, stipulato al par (2,5315%) su curva piatta 2,5%. Tassi simulati con un modello Ornstein-Uhlenbeck (a = 0,05, σ = 1%), 20.000 scenari, griglia mensile. Controparte: CDS 150 bp, R = 40%, quindi λ = 2,5%. Banca: spread proprio 80 bp.

| Tempo (anni) | EE (EUR) | ENE (EUR) |
| --- | --- | --- |
| 0,5 | 105.149 | −109.528 |
| 1,0 | 147.644 | −153.623 |
| 1,5 | 167.428 | −174.595 |
| 2,0 | 155.083 | −161.800 |
| 3,0 | 124.900 | −128.356 |
| 4,0 | 72.244 | −73.008 |
| 4,5 | 74.010 | −73.073 |

Il picco di EE è 182.391 EUR a 1,9 anni, subito prima del secondo fixing; l'EPE scontata è 117.673 EUR.

| Misura | Valore |
| --- | --- |
| CVA | 8.330 EUR |
| DVA | 4.678 EUR |
| CVA bilaterale (CVA − DVA) | 3.652 EUR |
| CVA come spread sul fisso | 1,79 bp l'anno |
| Approssimazione s × EPE × T | 8.825 EUR |

### Codice Python

```python
import numpy as np

# IRS payer 5Y, 10 mln, annuale, al par. Curva piatta y0 = 2,5% continua.
# Modello semplificato: y_t = y0 + x_t, x_t Ornstein-Uhlenbeck sotto Q.
N, y0, Tm = 10_000_000, 0.025, 5.0
pay = np.arange(1, 6, dtype=float)
K = (1 - np.exp(-y0*Tm))/np.sum(np.exp(-y0*pay))      # tasso par
a, sig = 0.05, 0.01
grid = np.linspace(0, Tm, 61)                          # griglia mensile
n = 20_000
rng = np.random.default_rng(8)

def swap_value(t, y, y_reset):
    """Valore del payer a t, dopo i pagamenti in t; y_reset = tasso dell'ultimo fixing."""
    rem = pay[pay > t + 1e-12]
    P = np.exp(-np.outer(y, rem - t))                  # P(t, T_i) per scenario
    float_leg = np.exp(y_reset)*P[:, 0] - P[:, -1]     # cedola già fissata + nozionale fittizio
    fixed_leg = K*P.sum(axis=1)
    return N*(float_leg - fixed_leg)

x = np.zeros(n); y_reset = np.full(n, y0)
EE, ENE = np.zeros(len(grid)), np.zeros(len(grid))
for i, t in enumerate(grid):
    if i > 0:
        dt = grid[i] - grid[i-1]
        x = x*np.exp(-a*dt) + sig*np.sqrt((1 - np.exp(-2*a*dt))/(2*a))*rng.standard_normal(n)
    if t < Tm:
        if i > 0 and np.isclose(t % 1, 0):             # data di fixing
            y_reset = y0 + x
        V = swap_value(t, y0 + x, y_reset)
        EE[i], ENE[i] = np.maximum(V, 0).mean(), np.minimum(V, 0).mean()

DF = np.exp(-y0*grid)
s_cpty, R = 0.0150, 0.40
Surv = np.exp(-s_cpty/(1 - R)*grid)                    # credit triangle
EEd = 0.5*(EE[:-1]*DF[:-1] + EE[1:]*DF[1:])
CVA = (1 - R)*np.sum(EEd*(Surv[:-1] - Surv[1:]))
Sb = np.exp(-0.0080/(1 - R)*grid)                       # spread proprio 80 bp
DVA = (1 - R)*np.sum(0.5*(-ENE[:-1]*DF[:-1] - ENE[1:]*DF[1:])*(Sb[:-1] - Sb[1:]))
EPE = np.trapezoid(EE*DF, grid)/Tm
print(f"Picco EE = {EE.max():,.0f} a t = {grid[EE.argmax()]:.2f} | EPE = {EPE:,.0f}")
print(f"CVA = {CVA:,.0f} | DVA = {DVA:,.0f} | BCVA = {CVA - DVA:,.0f}")
print(f"CVA running = {CVA/(N*np.sum(np.exp(-y0*pay)))*1e4:.2f} bp")
```

## 15. Econometria finanziaria: GARCH, copule, EVT, PCA

Questa è la parte in cui un background statistico fa la differenza. Quattro strumenti correggono i limiti del VaR "di base": il GARCH modella la volatilità che cambia nel tempo, le copule la dipendenza nelle code, l'EVT la forma della coda, la PCA riduce la curva dei tassi a pochi fattori. Riferimenti: McNeil, Frey ed Embrechts cap. 4, 5 e 7; Bollerslev (1986); Litterman e Scheinkman (1991).

### GARCH(1,1)

```latex
r_t = \sigma_t z_t, \qquad \sigma_t^2 = \omega + \alpha\, r_{t-1}^2 + \beta\, \sigma_{t-1}^2, \qquad \bar\sigma^2 = \frac{\omega}{1 - \alpha - \beta}
```

α + β è la persistenza (vicina a 1 nei dati reali); l'half-life di uno shock è ln(0,5)/ln(α + β). La stima è per massima verosimiglianza; con log-verosimiglianza gaussiana si parla di QMLE, consistente anche se z\_t non è normale. Il VaR filtrato (filtered historical simulation) combina la volatilità prevista dal GARCH con i quantili empirici dei residui standardizzati: reagisce subito ai cambi di regime. EWMA (RiskMetrics) è il caso particolare ω = 0, α = 1 − λ, β = λ.

### Copule

Per il teorema di Sklar ogni distribuzione congiunta si scrive come F(x\_1, …, x\_d) = C(F\_1(x\_1), …, F\_d(x\_d)): le marginali si modellano separatamente dalla struttura di dipendenza C. La copula gaussiana non ha dipendenza nelle code (gli eventi estremi diventano indipendenti al limite), mentre la copula t sì, con coefficiente:

```latex
\lambda_U = \lambda_L = 2\, t_{\nu+1}\!\left(-\sqrt{\frac{(\nu+1)(1-\rho)}{1+\rho}}\right)
```

È una domanda classica in chiave crediti: l'uso della copula gaussiana nei CDO è uno dei motivi per cui il rischio di default congiunti è stato sottostimato prima del 2008.

### Extreme Value Theory (Peaks Over Threshold)

Per il teorema di Pickands-Balkema-de Haan, oltre una soglia u alta le eccedenze seguono una Pareto generalizzata (GPD) con forma ξ e scala β. ξ > 0 indica code spesse (tipo Pareto); ξ = 0 code esponenziali (normale); ξ < 0 coda limitata. Con n osservazioni e n\_u eccedenze:

```latex
\text{VaR}_q = u + \frac{\beta}{\xi}\left[\left(\frac{n}{n_u}(1-q)\right)^{-\xi} - 1\right], \qquad \text{ES}_q = \frac{\text{VaR}_q + \beta - \xi u}{1 - \xi}
```

La scelta della soglia è un compromesso: troppo bassa introduce distorsione, troppo alta lascia poche osservazioni (si usa il mean excess plot). L'approccio di McNeil e Frey applica l'EVT ai residui di un GARCH.

### PCA sulla curva dei tassi

Si calcolano gli autovettori della matrice di covarianza delle variazioni giornaliere dei tassi ai vari nodi. Nei dati reali tre componenti spiegano oltre il 95% della varianza, con interpretazione stabile: livello (spostamento parallelo), pendenza (inclinazione), curvatura (gobba). Si usano per stress test coerenti, per ridurre i fattori nei modelli VaR e per costruire coperture.

### Esempio numerico

**GARCH** sui 2.000 rendimenti sintetici del portafoglio della sezione 9 (veri parametri del generatore: α = 0,08, β = 0,90). Stime: ω = 9,8 × 10⁻⁷, α = 0,071, β = 0,917, persistenza 0,987 e half-life 55 giorni. Volatilità incondizionata 0,88% al giorno, ma volatilità prevista per domani solo 0,57%: il mercato è in fase calma. Per questo il VaR 99% filtrato su 1 milione è 15.643 EUR, contro 21.994 della simulazione storica semplice. La curtosi dei residui standardizzati resta 5,25: il GARCH spiega parte delle code spesse, non tutte.

**Copule** con ρ = 0,5: probabilità che la seconda variabile sia sotto il quantile q dato che lo è la prima.

| Quantile q | Copula gaussiana | Copula t (ν = 4) |
| --- | --- | --- |
| 5% | 0,243 | 0,336 |
| 1% | 0,131 | 0,291 |
| 0,1% | 0,044 | 0,243 |

Con la gaussiana la probabilità di eventi estremi congiunti va verso zero; con la t si stabilizza vicino al coefficiente teorico 0,253.

**EVT** su 10.000 giorni sintetici, soglia al 95° percentile (500 eccedenze): ξ = 0,190 (code spesse), β = 5.665.

| Livello | VaR EVT | VaR empirico | VaR normale | ES EVT |
| --- | --- | --- | --- | --- |
| 99% | 22.997 | 23.308 | 19.230 | 32.484 |
| 99,5% | 28.692 | 27.951 | 21.292 | 39.511 |
| 99,9% | 45.193 | 45.250 | 25.544 | 59.875 |

Al 99,9% la normale sottostima il VaR di quasi la metà; l'EVT segue il dato empirico e permette di estrapolare oltre le osservazioni disponibili.

**PCA** su 1.000 giorni di variazioni sintetiche della curva (nodi da 1 a 30 anni): la prima componente spiega il 93,5% della varianza, la seconda il 4,5%, la terza l'1,6% (99,6% in totale). I loadings della prima sono tutti positivi (livello), quelli della seconda cambiano segno una volta (pendenza), quelli della terza due volte (curvatura).

### Codice Python

```python
import numpy as np
from scipy.optimize import minimize
from scipy.stats import norm, t as student_t, genpareto
from data import simulate_portfolio

ret = simulate_portfolio() @ np.array([0.6, 0.4])     # rendimento del portafoglio

# ---------- 1) GARCH(1,1) con QMLE gaussiana ----------
def garch_filter(params, r):
    omega, alpha, beta = params
    s2 = np.empty_like(r); s2[0] = r.var()
    for t in range(1, len(r)):
        s2[t] = omega + alpha*r[t-1]**2 + beta*s2[t-1]
    return s2

def neg_loglik(params, r):
    omega, alpha, beta = params
    if omega <= 0 or alpha < 0 or beta < 0 or alpha + beta >= 1:
        return 1e10                                    # vincoli di stazionarietà
    s2 = garch_filter(params, r)
    return 0.5*np.sum(np.log(2*np.pi*s2) + r**2/s2)

res = minimize(neg_loglik, [ret.var()*0.05, 0.05, 0.90], args=(ret,), method="Nelder-Mead",
               options={"xatol": 1e-10, "fatol": 1e-10, "maxiter": 20_000})
om, al, be = res.x
s2 = garch_filter(res.x, ret)
s_next = np.sqrt(om + al*ret[-1]**2 + be*s2[-1])
z = ret/np.sqrt(s2)                                    # residui standardizzati
print(f"alpha={al:.4f} beta={be:.4f} half-life={np.log(0.5)/np.log(al+be):.1f} giorni")
print(f"VaR99 FHS domani = {-np.quantile(z, 0.01)*s_next*1e6:,.0f} EUR su 1 mln")
# In produzione: from arch import arch_model; arch_model(ret*100, vol="GARCH", dist="t").fit()

# ---------- 2) Copula gaussiana vs copula t ----------
rng = np.random.default_rng(4)
rho, nu, n = 0.5, 4, 1_000_000
G = rng.multivariate_normal([0, 0], [[1, rho], [rho, 1]], n)
U_gauss = norm.cdf(G)
U_t = student_t.cdf(G*np.sqrt(nu/rng.chisquare(nu, n))[:, None], nu)
for q in [0.05, 0.01, 0.001]:
    pg = np.mean((U_gauss[:, 0] < q) & (U_gauss[:, 1] < q))/q
    pt = np.mean((U_t[:, 0] < q) & (U_t[:, 1] < q))/q
    print(f"q={q}: gaussiana={pg:.3f}  t={pt:.3f}")
print("tail dependence teorica t:", round(2*student_t.cdf(-np.sqrt((nu+1)*(1-rho)/(1+rho)), nu+1), 3))

# ---------- 3) EVT: Peaks Over Threshold ----------
ret_long = simulate_portfolio(n_days=10_000) @ np.array([0.6, 0.4])
loss = -ret_long*1e6
u = np.quantile(loss, 0.95)
exc = loss[loss > u] - u
xi, _, beta_gpd = genpareto.fit(exc, floc=0)
n_tot, n_u = len(loss), len(exc)
var_evt = lambda q: u + beta_gpd/xi*(((n_tot/n_u)*(1 - q))**(-xi) - 1)
es_evt = lambda q: (var_evt(q) + beta_gpd - xi*u)/(1 - xi)
for q in [0.99, 0.995, 0.999]:
    print(f"q={q}: VaR EVT={var_evt(q):,.0f} empirico={np.quantile(loss, q):,.0f} "
          f"normale={norm.ppf(q)*loss.std():,.0f} ES EVT={es_evt(q):,.0f}")

# ---------- 4) PCA sulla curva ----------
tenors = np.array([1, 2, 3, 5, 7, 10, 15, 20, 30.0])
rng = np.random.default_rng(9)
days = 1000
level = rng.normal(0, 3.0, days)[:, None]*np.ones(len(tenors))
slope = rng.normal(0, 5.0, days)[:, None]*(1 - np.exp(-tenors/5))
curv = rng.normal(0, 2.5, days)[:, None]*(tenors/5*np.exp(1 - tenors/5) - 0.5)
dC = level + slope + curv + rng.normal(0, 0.4, (days, len(tenors)))   # variazioni in bp
eigval, eigvec = np.linalg.eigh(np.cov(dC.T))
order = np.argsort(eigval)[::-1]; eigval, eigvec = eigval[order], eigvec[:, order]
print("Quota di varianza (%):", np.round(eigval[:3]/eigval.sum()*100, 2))
for k in range(3):
    print(f"PC{k+1}:", np.round(eigvec[:, k]*np.sign(eigvec[-1, k]), 2))
```

## 16. Strumenti, certificazioni e domande di colloquio

Per un ruolo junior in market risk contano tre cose dimostrabili: Python, una certificazione riconosciuta (FRM) e saper rispondere a voce, con i numeri, alle domande qui sotto.

### Strumenti

| Strumento | Cosa sapere | Dove si usa |
| --- | --- | --- |
| Python (numpy, pandas, scipy) | Tutto il codice di questa dispensa | Ovunque: risk engine, validazione, analisi |
| QuantLib-Python | Curve, IRS, swaption, calendari e convenzioni | Pricing tassi, validazione modelli |
| arch, statsmodels | GARCH, test statistici, regressioni | Modelli di volatilità, backtesting |
| Excel / VBA | Formule avanzate, tabelle pivot, macro | Test pratici ai colloqui, consulenza |
| SQL | Join, group by, funzioni finestra | Estrazione dati di posizioni e P&L |

### Certificazioni

**FRM (GARP)**: la più riconosciuta nel risk management. Nel 2026 la Parte I copre Foundations of Risk Management (20%), Quantitative Analysis (20%), Financial Markets and Products (30%), Valuation and Risk Models (30%); la Parte II include Market Risk Measurement and Management (20%) e Credit Risk (20%) ([GARP, FRM Study Guide 2026](https://www.garp.org/hubfs/GARP%20Design/frm/pdf/study-materials/2026/frm-study-guide-26.pdf)). Le sezioni 3–12 di questa dispensa coprono buona parte di Financial Markets and Products e di Valuation and Risk Models.

**CQF**: più orientato al pricing quantitativo, più costoso; utile se miri a ruoli da quant di front office più che di risk.

### Domande frequenti, con risposta breve

1. **Come si comporta il gamma di un'opzione ATM vicino a scadenza?** Esplode, come 1/√T: da 0,019 a un anno a 0,317 a un giorno nell'esempio della sezione 5. OTM e ITM invece tende a zero.
2. **Perché l'ES ha sostituito il VaR in FRTB?** Perché è coerente (subadditivo) e guarda alla gravità delle perdite oltre il quantile. Il 97,5% è scelto perché per una normale dà circa lo stesso numero del VaR 99%.
3. **Come fai il backtesting di un VaR?** Conto le eccezioni su 250 giorni, applico il semaforo di Basilea, poi Kupiec per la frequenza e Christoffersen per l'indipendenza.
4. **Perché la mediana di un'azione lognormale è sotto la media?** Per la correzione di Itô: la mediana cresce a μ − σ²/2, la media a μ.
5. **Cos'è il multi-curva e perché esiste?** Dal 2008 Euribor e OIS divergono per il rischio di credito e liquidità delle banche: si sconta a OIS (collaterale) e si proietta con una curva per tenor.
6. **Cosa succede alla CVA se la controparte ha collaterale giornaliero?** Si riduce molto: l'esposizione residua è solo quella nel margin period of risk.
7. **VaR a 10 giorni = VaR a 1 giorno × √10: quando è sbagliato?** Con autocorrelazione dei rendimenti, volatility clustering, posizioni non lineari o portafogli che cambiano nel periodo.
8. **Una put americana vale più di una europea? E una call?** La put sì (esercizio anticipato per incassare K prima); la call su titolo senza dividendi no.
9. **Brainteaser tipico.** Lanci due dadi: probabilità che la somma sia 7 dato che almeno uno è 6? Casi con almeno un 6: 11; tra questi con somma 7: 2. Risposta 2/11.
10. **Cosa ti dice un PLA test in zona rossa?** Che il modello di rischio non riproduce il P&L del front office: mancano fattori o le rivalutazioni divergono, e il desk passa al metodo standard.

## Fonti

### Normativa e documenti ufficiali (consultati il 6 novembre 2026)

- BCBS, [Minimum capital requirements for market risk](https://bis.org/bcbs/publ/d457.htm) (d457, 14 gennaio 2019): lo standard FRTB.
- Basel Framework, [MAR32 – Backtesting e PLA test](https://www.sif.admin.ch/dam/sif/de/dokumente/basel-3/MAR32.pdf.download.pdf/MAR32.pdf) (copia pubblicata dal Dipartimento federale svizzero delle finanze).
- Basel Framework, [MAR33 – Calcolo del requisito con modelli interni](https://www.sif.admin.ch/dam/sif/de/dokumente/basel-3/MAR33.pdf.download.pdf/MAR33.pdf) (stessa fonte).
- Basel Framework, [MAR99 – Guida sull'uso dei modelli interni](https://www.bis.org/committees/bcbs/basel-framework/81307/chapter.pdf) (tabella del semaforo FRTB).
- Regolamento (UE) n. 575/2013 (CRR), [art. 366, plus factor del backtesting](https://legislation.gov.uk/eur/2013/575/article/366/data.xht) (testo dell'articolo).
- Commissione europea, [Q&A sulle modifiche ai requisiti per il rischio di mercato](https://finance.ec.europa.eu/publications/questions-and-answers-banking-package-amending-market-risk-requirements-preserve-international-level_en) (4 giugno 2026): applicazione di FRTB nell'UE.
- BCBS, [Stress testing principles](https://www.bis.org/bcbs/publ/d450.htm) (17 ottobre 2018).
- BCE, [Euro short-term rate (€STR)](https://www.ecb.europa.eu/stats/financial_markets_and_interest_rates/euro_short-term_rate/html/eurostr_overview.en.html).
- EMMI, [Euribor – Hybrid methodology](https://emmi-benchmarks.eu/benchmarks/euribor/methodology).
- GARP, [FRM Study Guide 2026](https://www.garp.org/hubfs/GARP%20Design/frm/pdf/study-materials/2026/frm-study-guide-26.pdf).

### Paper originali

- Kupiec, P. (1995), [Techniques for verifying the accuracy of risk measurement models](https://econpapers.repec.org/RePEc:fip:fedgfe:95-24), Federal Reserve, FEDS 95-24.
- Christoffersen, P. (1998), [Evaluating Interval Forecasts](https://econpapers.repec.org/RePEc:ier:iecrev:v:39:y:1998:i:4:p:841-62), International Economic Review 39(4), 841–862.
- Artzner, P., Delbaen, F., Eber, J.-M., Heath, D. (1999), [Coherent Measures of Risk](https://ideas.repec.org/a/bla/mathfi/v9y1999i3p203-228.html), Mathematical Finance 9(3), 203–228.
- Hagan, P., Kumar, D., Lesniewski, A., Woodward, D. (2002), [Managing Smile Risk](https://wilmott.com/?p=3482), Wilmott Magazine.
- Black, F., Scholes, M. (1973), The Pricing of Options and Corporate Liabilities, Journal of Political Economy 81(3).
- Vasicek, O. (1977), An Equilibrium Characterization of the Term Structure, Journal of Financial Economics 5(2).
- Hull, J., White, A. (1990), Pricing Interest-Rate-Derivative Securities, Review of Financial Studies 3(4).
- Bollerslev, T. (1986), Generalized Autoregressive Conditional Heteroskedasticity, Journal of Econometrics 31(3).
- Litterman, R., Scheinkman, J. (1991), Common Factors Affecting Bond Returns, Journal of Fixed Income 1(1).

### Testi

- J. Hull, Options, Futures and Other Derivatives (Pearson): sezioni 1–8.
- J. Hull, Risk Management and Financial Institutions (Wiley): sezioni 9–13.
- P. Jorion, Value at Risk (McGraw-Hill): sezioni 9 e 11.
- S. Shreve, Stochastic Calculus for Finance I e II (Springer): sezione 1.
- A. McNeil, R. Frey, P. Embrechts, Quantitative Risk Management (Princeton University Press): sezioni 10 e 15.
- D. Brigo, F. Mercurio, Interest Rate Models – Theory and Practice (Springer): sezioni 7–8.
- J. Gregory, The xVA Challenge (Wiley): sezione 14.
- P. Glasserman, Monte Carlo Methods in Financial Engineering (Springer): sezione 2.
- J. Gatheral, The Volatility Surface (Wiley): sezione 6.

I paper senza link e i testi sono citati come bibliografia standard; edizioni e capitoli possono variare tra le versioni. Tutti i dati numerici degli esempi sono illustrativi o sintetici, non quotazioni di mercato.
