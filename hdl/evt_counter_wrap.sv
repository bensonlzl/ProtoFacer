module evt_counter_wrap #(parameter MAX_EVENT = 40000) (
    input wire clk_in,
    input wire rst_in,
    input wire evt_in,
    output logic[$clog2(MAX_EVENT)-1:0] count_out
);
    logic prev_evt_val;
    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            count_out <= 0;
        end else begin 
            if (evt_in) begin
                if (count_out + 1 == MAX_EVENT) begin 
                    count_out <= 0;
                end
                else begin 
                    count_out <= count_out + 1;
                end
            end else begin
                count_out <= count_out;
            end
        end
        prev_evt_val <= evt_in;

    end
endmodule