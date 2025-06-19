module fpu(
    input logic          clock,      //clock 100KHz
    input logic          reset,
    input logic          start,
    input logic  [31:0]  op_A_in,    //parcelas da soma\sub
    input logic  [31:0]  op_B_in,    //       ''

    output logic [31:0]  data_out,  //resultado
    output logic [3:0]   status_out
);

    //Declaração dos sinais
    logic        sign_a;
    logic [6:0]  exp_a; 
    logic [23:0] mantissa_a;

    logic        sign_b;
    logic [6:0]  exp_b;
    logic [23:0] mantissa_b;

    
    //Sinais Internos
    logic        [25:0] mantissa_result;
    logic        [6:0]  exp_result;
    logic               sign_result;


    //Para ALIGN
    logic signed [7:0] diff_reg;           //diferença entre expoent_a e expoent_b (signed permite negativo)
    logic        [24:0] mantissa_a_shifted; //se shift ta mantissa a
    logic        [24:0] mantissa_b_shifted; //se shift da mantissa b
    logic        [6:0]  exp_aligned;        //exp alinhado

    //Para ROUND
    logic guard_bit, round_bit, sticky_bit;
    logic [25:0] rounded_mantissa;
    

    //Separação dos bits | Ligação dos Sinais
    assign sign_a            = op_A_in[31];     //primeiro bit (sinal)
    assign exp_a             = op_A_in[30:24];  //2° ao 6° bit (expoente)
    assign mantissa_a        = op_A_in[23:0];   //7° ao 32° bit (mantissa)

    assign sign_b             = op_B_in[31];    
    assign exp_b              = op_B_in[30:24]; 
    assign mantissa_b         = op_B_in[23:0];  


    //Registradores internos para armazenar os operandos (evita problemas caso o dado mude no meio da execução)
    logic        sign_a_reg, sign_b_reg;
    logic [6:0]  exp_a_reg, exp_b_reg;
    logic [24:0] mant_a_reg, mant_b_reg; //bit extra para shift 

    assign diff_comb = exp_a_reg - exp_b_reg;

typedef enum logic [3:0] { //one-hot para poder combinar estados
    EXACT     = 4'b0001,
    INEXACT   = 4'b0010, 
    OVERFLOW  = 4'b0100, 
    UNDERFLOW = 4'b1000
}status_t;

typedef enum logic [2:0] {
    IDLE,         //recebe dados, extrai campos
    ALIGN,        //alinha expoentes e ajusta mantissas
    CALC,         //soma ou subtrai mantissas (com sinal)
    NORMALIZE,    //ajusta mantissa e expoente com shift
    ROUND,        //arredondamento e checagem de flags
    PACK          //junta o resultado final e atualiza saídas
} state_t;

state_t state;

    always_ff @(posedge clock or negedge reset) begin
        if(!reset) begin
            state       <= IDLE;
            exp_result  <= 0; 
            diff_reg <= 0; 
        end else begin
            diff_reg <= exp_a_reg - exp_b_reg;

//!!! Debugs atrasados em um estado para garantir que os sinais atualizem !!!!

            case(state)
                IDLE: begin //Copia op_A_in e op_B_in para reg | caso os sinais mudem durante a execução não vai interferir

                if(start) begin
                    sign_a_reg <= sign_a;
                    exp_a_reg  <= exp_a;
                    mant_a_reg <= {1'b0, mantissa_a}; //concatena um bit a esquerda para ficar 25 bits

                    sign_b_reg <= sign_b;
                    exp_b_reg  <= exp_b;
                    mant_b_reg <= {1'b0, mantissa_b};

                    $display("\n================================================");
                    $display("Recebi dado A: %b\n", {sign_a, exp_a, mantissa_a});
                    $display("Recebi dado B: %b\n", {sign_b, exp_b, mantissa_b});

                    $display("Sinal A: %b\n", sign_a);
                    $display("Sinal B: %b\n", sign_b);

                    $display("Expoente A: %b (%0d)\n", exp_a, exp_a);
                    $display("Expoente B: %b (%0d)\n", exp_b, exp_b);

                    $display("Mantissa A: %b (%0d)\n", mantissa_a, mantissa_a);
                    $display("Mantissa B: %b (%0d)  ", mantissa_b, mantissa_b);
                    $display("================================================\n");
                    status_out <= 4'b0000; 
                    state <= ALIGN;
                end
                end

                ALIGN: begin //Alinhar expoentes e mantissas para ficar pronto para o calculo
                   //Calcular a diferença

                    //Menor expoente se adapta ao maior
                    if(exp_a_reg > exp_b_reg) begin //A maior que B
                        mantissa_a_shifted <= mant_a_reg;              // mantissa com expoente maior fica como está
                        mantissa_b_shifted <= mant_b_reg >> diff_reg; //diff bits à direita. Zeros preenchidos a esquerda
                        exp_aligned        <= exp_a_reg;               //Usa o maior expoente
                    end

                    else if(exp_a_reg < exp_b_reg) begin //B maior que A
                        mantissa_b_shifted <= mant_b_reg;         
                        mantissa_a_shifted <= mant_a_reg >> -diff_reg; //inverte o sinal do resultado pois quando b > 0, diff é negativo 
                        exp_aligned        <= exp_b_reg;         
                    end 
                    else begin                      //Iguais
                        mantissa_a_shifted <= mant_a_reg;
                        mantissa_b_shifted <= mant_b_reg;
                        exp_aligned        <= exp_a_reg;
                    end
                    state <= CALC;
                end

                CALC: begin  // Somar/subtrair mantissas
                $display("\n----------------- ALIGN STATE -----------------");
                $display("diff (exp_a - exp_b): %b (%0d)\n", diff_comb,diff_comb);
                $display("mantissa_a_shifted:   %b (%0d)\n", mantissa_a_shifted, mantissa_a_shifted);
                $display("mantissa_b_shifted:   %b (%0d)\n", mantissa_b_shifted, mantissa_b_shifted);
                $display("exp_aligned:          %b (%0d)\n", exp_aligned, exp_aligned);
                //$display("exp_result:           %b (%0d)",   exp_result, exp_result);
                $display("-----------------------------------------------\n");

                //Sinais Iguais     -> Soma
                //Sinais Diferentes -> Subtrair Maior - Menor

                //Soma direta
                if(sign_a_reg == sign_b_reg) begin
                    mantissa_result <= mantissa_a_shifted + mantissa_b_shifted;
                    sign_result     <= sign_a_reg;
                end else begin

                    //Subtrações
                    if(mantissa_a_shifted >= mantissa_b_shifted) begin
                        mantissa_result <= mantissa_a_shifted - mantissa_b_shifted;
                        sign_result     <= sign_a_reg;
                    end else begin
                    if(mantissa_a_shifted <= mantissa_b_shifted) begin
                        mantissa_result <= mantissa_b_shifted - mantissa_a_shifted;
                        sign_result     <= sign_b_reg;
                    end
                    end
                end
                exp_result <= exp_aligned;
                state <= NORMALIZE;

                end

                NORMALIZE: begin // Normalizar mantissa (remover zeros a esquerda) e ajustar expoente conforme necessário
                $display("\n----------------- CALC STATE -----------------");
                $display("mantissa_a_shifted: %b (%0d)\n", mantissa_a_shifted, mantissa_a_shifted);
                $display("mantissa_b_shifted: %b (%0d)\n", mantissa_b_shifted, mantissa_b_shifted);
                $display("mantissa_result:    %b (%0d)\n", mantissa_result, mantissa_result);
                $display("sign_result:        %b (%0d)\n", sign_result, sign_result);
                $display("exp_result:         %d (%0d)\n", exp_result, exp_result);
                $display("-----------------------------------------------\n");



                //Verifica se excedeu limite da mantissa
                if(mantissa_result[25]) begin
                    guard_bit <= mantissa_result[0];           // salva o menos significativo
                    round_bit <= 1'b0;                         // sem bits extras aqui (shift 1 bit só)
                    sticky_bit <= 1'b0;                        

                    mantissa_result <= mantissa_result >> 1; //Desloca mantissa para direita, descartando o bit excedente
                    exp_result      <= exp_result + 1;       //Aumenta o expoente
                
                    //Verifica Overflow
                    if ((exp_result + 1)>= 7'd127 ) begin
                        $display("-> OVERFLOW ");
                        status_out <= status_out | OVERFLOW;
                        mantissa_result <= 0;
                        exp_result <= 0;
                        state <= ROUND;
                    end 
                    else begin
                        state <= NORMALIZE;
                    end
                end 


                //Verifica se Mantissa_result[24] é 1 e arruma expoente
                else if(mantissa_result[24] == 0 && exp_result > 0) begin
                    mantissa_result <= mantissa_result << 1;    //Desloca para esquerda
                    exp_result      <= exp_result - 1;          //Arruma Expoente 
                    state <= NORMALIZE;                         //Testa novamente
                end 
                
                //Número normalizado, sem erro
                else begin
                    status_out <= EXACT;
                    state <= ROUND;
                end
                end
    
                // Arredondar e detectar flags
                ROUND: begin
                $display("\n----------------- NORMALIZE STATE -----------------");
                $display("mantissa_a_shifted: %b (%0d)\n", mantissa_a_shifted, mantissa_a_shifted);
                $display("mantissa_b_shifted: %b (%0d)\n", mantissa_b_shifted, mantissa_b_shifted);
                $display("mantissa_result:    %b (%0d)\n", mantissa_result, mantissa_result);
                $display("sign_result:        %b (%0d)\n", sign_result, sign_result);
                $display("exp_result:         %d (%0d)\n", exp_result, exp_result);
                $display("status_out:         %b \n", status_out);
                $display("----------------------------------------------------\n");
                

                //se alguém "se passou", arredonda pra cima
                if (guard_bit && (round_bit || sticky_bit || mantissa_result[0])) begin
                      rounded_mantissa = mantissa_result + 1;
                    
                        // Se estourar mantissa após arredondar, shift right
                        if (mantissa_result[25]) begin
                            mantissa_result <= mantissa_result >> 1;
                            exp_result <= exp_result + 1;
                        end else begin
                             mantissa_result <= rounded_mantissa;
                    end
                end
                
                state <= PACK;
                
                end
    

                // Montar saída data_out e status_out
                PACK: begin 
                $display("\n----------------- ROUND STATE -----------------");
                $display("mantissa_a_shifted: %b (%0d)\n", mantissa_a_shifted, mantissa_a_shifted);
                $display("mantissa_b_shifted: %b (%0d)\n", mantissa_b_shifted, mantissa_b_shifted);
                $display("mantissa_result:    %b (%0d)\n", mantissa_result, mantissa_result);
                $display("sign_result:        %b (%0d)\n", sign_result, sign_result);
                $display("exp_result:         %d (%0d)\n", exp_result, exp_result);
                $display("status_out:         %b \n", status_out);
                $display("----------------------------------------------------\n");
                   
                    data_out <= {sign_result, exp_result, mantissa_result[23:0]};

                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule