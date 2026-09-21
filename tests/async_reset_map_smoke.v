module async_reset_map_smoke (
    input  wire clk,
    input  wire en,
    input  wire sr,
    input  wire ar,
    input  wire d,
    output reg  q_sync_reset,
    output reg  q_sync_set,
    output reg  q_async_reset,
    output reg  q_async_set
);
    always @(posedge clk)
        if (en) begin
            if (sr) q_sync_reset <= 1'b0;
            else q_sync_reset <= d;
        end

    always @(posedge clk)
        if (en) begin
            if (sr) q_sync_set <= 1'b1;
            else q_sync_set <= d;
        end

    always @(posedge clk or posedge ar)
        if (ar) q_async_reset <= 1'b0;
        else if (en) q_async_reset <= d;

    always @(posedge clk or posedge ar)
        if (ar) q_async_set <= 1'b1;
        else if (en) q_async_set <= d;
endmodule
