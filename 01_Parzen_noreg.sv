























#(
    parameter WINDOW_SIZE_POW2 = 10,    //窗口大小 N
    parameter COEFF_FRAC_BITS = 16,     //小数位个数
    parameter COEFF_INT_BITS = WINDOW_SIZE_POW2,    //整数位个数，必须大于等于WINDOW_SIZE_POW2
    parameter COEFF_BITS = COEFF_FRAC_BITS + COEFF_INT_BITS //结果大小（整数位位数和小数位位数之和）
)
(
    input   clk,
    input   rst,

    output [COEFF_BITS-1:0] window_out,
    output  window_out_valid

);


// Sizes
// When multiplying, the sizes add.
// B * B is B_SIZE + BSIZE
// B2 * B is B2_SIZE + B_SIZE
localparam B_INT_BITS = COEFF_INT_BITS;
localparam B2_INT_BITS = B_INT_BITS + B_INT_BITS;
localparam B3_INT_BITS = B2_INT_BITS + B_INT_BITS;

// When multiplying, the fractionals add with the same rules
localparam B_FRAC_BITS = COEFF_FRAC_BITS;
localparam B2_FRAC_BITS = B_FRAC_BITS + B_FRAC_BITS;
localparam B3_FRAC_BITS = B2_FRAC_BITS + B_FRAC_BITS;


// Count down from WINDOW_SIZE_POW2/2 to 0 and then back up again
logic [WINDOW_SIZE_POW2-1:0] window_counter;    //窗口计数器
logic window_counter_valid;
logic window_counting_down;


always @(posedge clk) 
    begin
        if (rst) begin
            window_counter <= 1 << (WINDOW_SIZE_POW2-1);
            window_counting_down <= 1'b1;
            window_counter_valid <= 1'b0;


        end
        else begin
            window_counter_valid <= 1'b1;

            if (window_counting_down) begin
////????    
////????
                window_counter <= window_counter + 1;
            end
            else begin
                window_counter <= window_counter - 1;
            end
        end
        else begin
            if (window_counter == 1 << (WINDOW_SIZE_POW2-1)) begin
                window_counting_down = 1;
                window_counter <= window_counter - 1;

            end
            else begin
                window_counter <= window_counter + 1;

            end
        end

    end
end

// window_counter is an integer, to make it fractional
// window_counter << COEFF_FRAC_BITS

logic [B_INT_BITS-1:-B_FRAC_BITS] abs_n;    //将其转化为定点格式

// Integer part of abs(n) is my counter
assign abs_n[B_INT_BITS-1:0] = window_counter;
// Fractional bits are empty
assign abs_n[-1:-B_FRAC_BITS] = '0;


// b_coeff is window_counter >> (WINDOW_SIZE_POW2-1)
// Combined is window_counter << (COEFF_FRAC_BITS - (WINDOW_SIZE_POW2-1))
// COEFF_FRAC_BITS is >= WINDOW_SIZE_POW2, when COEFF_FRAC_BITS == WINDOW_SIZE_POW2, shift right by 1

logic [B_INT_BITS-1:-B_FRAC_BITS] b_coeff_f;
assign b_coeff_f = abs_n >>> (WINDOW_SIZE_POW2 - 1);


logic [B2_INT_BITS-1:-B2_FRAC_BITS] b2_coeff_f;

assign b2_coeff_f = b_coeff_f * b_coeff_f;

logic [B3_INT_BITS-1:-B3_FRAC_BITS] b3_coeff_f;

assign b3_coeff_f = b2_coeff_f * b_coeff_f;

logic [B_INT_BITS-1:-B_FRAC_BITS] b1_coeff;
logic [B_INT_BITS-1:-B_FRAC_BITS] b2_coeff;
logic [B_INT_BITS-1:-B_FRAC_BITS] b3_coeff;


assign b1_coeff = b_coeff_f;
assign b2_coeff = b2_coeff_f[B_INT_BITS-1:-B_FRAC_BITS];
assign b3_coeff = b3_coeff_f[B_INT_BITS-1:-B_FRAC_BITS];


// create scaled values
logic [B_INT_BITS-1:-B_FRAC_BITS] c6b1_coeff;
logic [B_INT_BITS-1:-B_FRAC_BITS] c6b2_coeff;
logic [B_INT_BITS-1:-B_FRAC_BITS] c6b3_coeff;
logic [B_INT_BITS-1:-B_FRAC_BITS] c2b3_coeff;


assign c6b1_coeff = b1_coeff*6;
assign c6b2_coeff = b2_coeff*6;
assign c6b3_coeff = b3_coeff*6;
assign c2b3_coeff = b3_coeff*2;


logic [B_INT_BITS-1:-B_FRAC_BITS] one_const;
logic [B_INT_BITS-1:-B_FRAC_BITS] two_const;

assign one_const[B_INT_BITS-1:0] = 1;
assign one_const[-1:-B_FRAC_BITS] = '0;

assign two_const[B_INT_BITS-1:0] = 2;
assign two_const[-1:-B_FRAC_BITS] = '0;

// Polynomials
logic [B_INT_BITS-1:-B_FRAC_BITS] f1;
logic [B_INT_BITS-1:-B_FRAC_BITS] f2;
logic [WINDOW_SIZE_POW2-1:0] f_n;

assign f_n = window_counter;

assign f1 = one_const + c6b3_coeff - c6b2_coeff;
assign f2 = two_const + c6b2_coeff - c6b1_coeff - c2b3_coeff;

logic [B_INT_BITS-1:-B_FRAC_BITS] window_out_i;

assign window_out_i = (f_n[WINDOW_SIZE_POW2-1:WINDOW_SIZE_POW2-2] > 0) ? 
                        f2 : f1;
