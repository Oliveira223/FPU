# FPU (Floating-point unit)

### Objetivo
O objetivo desse projeto é implementar uma __unidade de ponto flutuante (FPU))__ seguindo o padrão IEE-754, porém com um formato personalizado para o __bit se sinal__, __expoente__ e __mantissa__. A FPU será capaz de executar operações de soma e subtração,sinalizando por meio de _flags_ se o resultado foi __exato__ ou __inexato__ além de detectar se ocorreu __overflow__ e __underflow__.

### Definição do tamanho do campo
Para determinar o número de bits do __expoente (X)__ e da __mantissa (Y)__, foi utilizazod o seguinte critério:

$$x = 8 \pm (\sum d \space \\% \space 4)$$

Onde
- X é o número de bits do expoente
- $\sum_d$ é o somatório dos sígitos da matrícula.
- % 4 representa o resto da divisão inteira por 4.
- Sinal $\pm$ é determinado pelo dígito verificador da matrícula
  - Se par, negativo
  - Se ímpar, positivo.
- A quantidade de bits da mantissa (Y) é dado por:

$$Y = 31 - X$$ 
    
#### Cálculo com a matrícula:
  $\rightarrow$ Matrícula: 24104738-0
- Somatório dos dígitos:

  $$\sum d = 2 + 4 +1 + 0 + 4 + 7 + 3 + 9 + 0 = 29$$
- Digíto verificado = 0 \rightarrow par. Então utilizamos o sinal negativo
- Cálculo do expoente:
  
$$X = 8 - (29 \space \\% \space 4) = 8 + (1) = 7$$

- Cálculo da mantissa:
  
$$Y = 31 - X = 31 - 7 = 24$$

#### Resultado 
| Campo | Valor |
| ----- | ----- |
| Sinal | 1 bit |
| Expoente | 7 bits |
| Mantissa | 24 bits |



### Descrição do Projeto
Esse projeto foi implementando em Verilog utilzando uma máquinna de estados finita (FSM) para controlar e organizar o processamento e fluxo dos dados em etapas sequenciais. 
A FPU recebe dois valores (operandos) de 32 bits e entãos os divide da seguinte forma:
- bit[31] : Sinal (0 representa positivo, 1 representa negativo
- bits[30:24] : Expoente de 7 bits
- bits[23:0] : Mabtissa de 25 bits

O programa então, realiza as devidas operações com os bits separados e ao final, reagrupo novamente no formato de 32 bits. 

### Maquina de Estados Finita
O funcionamento dessa FPU foi divida em seis estados, cada um com funções específicas como explicado abaixo:

| Estado      | Descrição |
| ----------- | ---- |
| `IDLE`      | Recebe os operandos `op_A_in` e `op_B_in` e armazena os dados em registradores internos, o que garante que os valores não sejam alterados no meio da operação |
| `ALIGN`     | Compara os expoentes dos operandos e desloca a mantissa do operando com menor expoente para alinhar os números.|
| `CALC`      | Realiza a soma ou subtração das mantissas, considerando os sinais dos operandos. |
| `NORMALIZE` | Ajusta a mantissa resultante para a forma normalizada (`1.xxx...`) e aarruma o expoente. |
| `ROUND`     | Aplica arredondamento caso necessário e verifica a ocorrência das condições: **INEXACT**, **OVERFLOW** e **UNDERFLOW**.|
| `PACK`      | Reagrupa o __sinal__, __expoente__ e __mantissa__ final para formar o valor de saída `data_out`. Atualiza as **flags de status** (`status_out`).|


### Sinais de Estados
Essa FPU sinaliza o resultado da operão por meio de um vetor `status_out` do tipo one-hot, permitindo a "soma" dos estados caso ocorra mais de um simultaneamente. Os possíveis estados são:
| Bit | Flag | Significado |
| --- | ---- | ----------- |
| 0001 | `EXACT`     | A operação resultou um valor com representação exata |
| 0010 | `INEXACT`   | Houve perda de precisão (bits foram descartados)|
| 0100 | `OVERFLOW`  | O expoente final excedeu o valor máximo representável |
| 1000 | `UNDERFLOW` | O expoente final foi menor que o mínimo representável |



### Como Executar o Programa
1. Inicie a ferramenta Questa.
2. Abra a pasta `TB` no Questa.
3. Use o comando `do sim.do`