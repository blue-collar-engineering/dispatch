import React, { useState, useEffect, useRef } from 'react';

const BreakoutGame = () => {
  const canvasRef = useRef(null);
  const [gameOver, setGameOver] = useState(false);
  const [score, setScore] = useState(0);

  useEffect(() => {
    const canvas = canvasRef.current;
    const ctx = canvas.getContext('2d');
    let animationFrameId;

    // Game objects
    const paddle = {
      x: canvas.width / 2 - 40,
      y: canvas.height - 20,
      width: 80,
      height: 10,
      dx: 8
    };

    const ball = {
      x: canvas.width / 2,
      y: canvas.height - 30,
      radius: 6,
      dx: 4,
      dy: -4
    };

    // Create bricks with colors
    const brickRowCount = 4;
    const brickColumnCount = 8;
    const bricks = [];

    // Define colors for each row
    const rowColors = [
      '#FF4136', // Red
      '#FF851B', // Orange
      '#2ECC40', // Green
      '#0074D9'  // Blue
    ];

    for (let c = 0; c < brickColumnCount; c++) {
      bricks[c] = [];
      for (let r = 0; r < brickRowCount; r++) {
        bricks[c][r] = {
          x: 0,
          y: 0,
          status: 1,
          color: rowColors[r]
        };
      }
    }

    // Event listeners for paddle movement
    let rightPressed = false;
    let leftPressed = false;

    const keyDown = (e) => {
      if (e.key === 'Right' || e.key === 'ArrowRight') rightPressed = true;
      if (e.key === 'Left' || e.key === 'ArrowLeft') leftPressed = true;
    };

    const keyUp = (e) => {
      if (e.key === 'Right' || e.key === 'ArrowRight') rightPressed = false;
      if (e.key === 'Left' || e.key === 'ArrowLeft') leftPressed = false;
    };

    document.addEventListener('keydown', keyDown);
    document.addEventListener('keyup', keyUp);

    // Game loop
    const draw = () => {
      // Clear canvas
      ctx.clearRect(0, 0, canvas.width, canvas.height);

      // Draw boundary lines
      ctx.strokeStyle = '#666666';
      ctx.lineWidth = 2;
      ctx.beginPath();
      // Left boundary
      ctx.moveTo(0, 0);
      ctx.lineTo(0, canvas.height);
      // Top boundary
      ctx.moveTo(0, 0);
      ctx.lineTo(canvas.width, 0);
      // Right boundary
      ctx.moveTo(canvas.width, 0);
      ctx.lineTo(canvas.width, canvas.height);
      ctx.stroke();

      // Draw paddle
      ctx.fillStyle = '#0095DD';
      ctx.fillRect(paddle.x, paddle.y, paddle.width, paddle.height);

      // Draw ball
      ctx.beginPath();
      ctx.arc(ball.x, ball.y, ball.radius, 0, Math.PI * 2);
      ctx.fillStyle = '#0095DD';
      ctx.fill();
      ctx.closePath();

      // Draw bricks
      const brickWidth = 48;
      const brickHeight = 20;
      const brickPadding = 8;
      const brickOffsetTop = 30;
      const brickOffsetLeft = 50;

      for (let c = 0; c < brickColumnCount; c++) {
        for (let r = 0; r < brickRowCount; r++) {
          const b = bricks[c][r];
          if (b.status === 1) {
            const brickX = (c * (brickWidth + brickPadding)) + brickOffsetLeft;
            const brickY = (r * (brickHeight + brickPadding)) + brickOffsetTop;
            b.x = brickX;
            b.y = brickY;

            ctx.fillStyle = b.color;
            ctx.fillRect(brickX, brickY, brickWidth, brickHeight);

            // Add a slight 3D effect with a darker border
            ctx.strokeStyle = '#000';
            ctx.strokeRect(brickX, brickY, brickWidth, brickHeight);
          }
        }
      }

      // Move paddle
      if (rightPressed && paddle.x < canvas.width - paddle.width) {
        paddle.x += paddle.dx;
      } else if (leftPressed && paddle.x > 0) {
        paddle.x -= paddle.dx;
      }

      // Move ball
      ball.x += ball.dx;
      ball.y += ball.dy;

      // Ball collision with walls
      if (ball.x + ball.dx > canvas.width - ball.radius || ball.x + ball.dx < ball.radius) {
        ball.dx = -ball.dx;
      }
      if (ball.y + ball.dy < ball.radius) {
        ball.dy = -ball.dy;
      }

      // Ball collision with paddle
      if (ball.y + ball.dy > canvas.height - ball.radius - paddle.height) {
        if (ball.x > paddle.x && ball.x < paddle.x + paddle.width) {
          ball.dy = -ball.dy;
        } else if (ball.y + ball.dy > canvas.height - ball.radius) {
          setGameOver(true);
          return;
        }
      }

      // Ball collision with bricks
      for (let c = 0; c < brickColumnCount; c++) {
        for (let r = 0; r < brickRowCount; r++) {
          const brick = bricks[c][r];
          if (brick.status === 1) {
            if (ball.x > brick.x &&
              ball.x < brick.x + brickWidth &&
              ball.y > brick.y &&
              ball.y < brick.y + brickHeight) {
              ball.dy = -ball.dy;
              brick.status = 0;
              setScore(prevScore => prevScore + 1);
            }
          }
        }
      }

      animationFrameId = requestAnimationFrame(draw);
    };

    draw();

    return () => {
      cancelAnimationFrame(animationFrameId);
      document.removeEventListener('keydown', keyDown);
      document.removeEventListener('keyup', keyUp);
    };
  }, []);

  return (
    <div className="flex flex-col items-center justify-center min-h-screen bg-gray-100">
      <div className="max-w-[800px] w-full mx-auto px-4">
        <div className="w-[500px] mx-auto">
          <div className="text-left mb-4 text-lg font-bold">Score: {score}</div>
          {gameOver && (
            <div className="text-left mb-4 text-red-600 font-bold">Game Over!</div>
          )}
          <canvas
            ref={canvasRef}
            width={500}
            height={400}
            className="border-2 border-blue-500 bg-white"
          />
          <div className="mt-4 text-sm text-gray-600">
            Use left and right arrow keys to move the paddle
          </div>
        </div>
      </div>
    </div>
  );
};

export default BreakoutGame;
