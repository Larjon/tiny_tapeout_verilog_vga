`default_nettype none

module tt_um_vga_example(
  input  wire [7:0] ui_in,
  output wire [7:0] uo_out,
  input  wire [7:0] uio_in,
  output wire [7:0] uio_out,
  output wire [7:0] uio_oe,
  input  wire       ena,
  input  wire       clk,
  input  wire       rst_n
);

  // VGA signals
  wire hsync;
  wire vsync;
  reg  [1:0] R;
  reg  [1:0] G;
  reg  [1:0] B;
  wire video_active;
  wire [9:0] pix_x;
  wire [9:0] pix_y;

  // TinyVGA PMOD
  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

  // Unused
  assign uio_out = 8'b0;
  assign uio_oe  = 8'b0;

  // Suppress unused warnings
  wire _unused_ok = &{ena, ui_in, uio_in};

  // Sync generator
  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(pix_x),
    .vpos(pix_y)
  );

  // ------------------------------------------------------------
  // DVD-style bouncing "ball" (square), update once per frame
  // ------------------------------------------------------------
  localparam [9:0] H_VISIBLE = 10'd640;
  localparam [9:0] V_VISIBLE = 10'd480;

  localparam [9:0] HALF_SIZE = 10'd12;   // half-width/height of the square

  localparam [9:0] X_MIN = HALF_SIZE;
  localparam [9:0] Y_MIN = HALF_SIZE;
  localparam [9:0] X_MAX = 10'd640 - HALF_SIZE - 10'd1;
  localparam [9:0] Y_MAX = 10'd480 - HALF_SIZE - 10'd1;

  reg [9:0] obj_x;
  reg [9:0] obj_y;

  // signed velocities (no multiplication needed)
  reg signed [9:0] vx;
  reg signed [9:0] vy;

  // update position once per frame
  always @(posedge vsync or negedge rst_n) begin
    if (!rst_n) begin
      obj_x <= 10'd320;
      obj_y <= 10'd240;
      vx <= 10'sd3;
      vy <= 10'sd2;
    end else begin
      // tentative next (keep it simple: add/sub with explicit signed cast)
      // compute next x
      if (vx[9] == 1'b0) begin
        // vx >= 0
        if (obj_x + vx[9:0] >= X_MAX) begin
          obj_x <= X_MAX;
          vx <= -vx;
        end else begin
          obj_x <= obj_x + vx[9:0];
        end
      end else begin
        // vx < 0  => subtract magnitude
        if (obj_x <= X_MIN + (~vx[9:0] + 10'd1)) begin
          obj_x <= X_MIN;
          vx <= -vx;
        end else begin
          obj_x <= obj_x - (~vx[9:0] + 10'd1);
        end
      end

      // compute next y
      if (vy[9] == 1'b0) begin
        // vy >= 0
        if (obj_y + vy[9:0] >= Y_MAX) begin
          obj_y <= Y_MAX;
          vy <= -vy;
        end else begin
          obj_y <= obj_y + vy[9:0];
        end
      end else begin
        // vy < 0 => subtract magnitude
        if (obj_y <= Y_MIN + (~vy[9:0] + 10'd1)) begin
          obj_y <= Y_MIN;
          vy <= -vy;
        end else begin
          obj_y <= obj_y - (~vy[9:0] + 10'd1);
        end
      end
    end
  end

  // ------------------------------------------------------------
  // Draw square: |x-obj_x| <= HALF_SIZE and |y-obj_y| <= HALF_SIZE
  // (no multipliers)
  // ------------------------------------------------------------
  wire [9:0] dx = (pix_x >= obj_x) ? (pix_x - obj_x) : (obj_x - pix_x);
  wire [9:0] dy = (pix_y >= obj_y) ? (pix_y - obj_y) : (obj_y - pix_y);

  wire obj_on = (dx <= HALF_SIZE) && (dy <= HALF_SIZE);

  // ------------------------------------------------------------
  // Colors
  // ------------------------------------------------------------
  always @(*) begin
    R = 2'b00; G = 2'b00; B = 2'b00; // black background

    if (video_active) begin
      if (obj_on) begin
        R = 2'b11; G = 2'b00; B = 2'b00; // red square "ball"
      end
    end
  end

endmodule