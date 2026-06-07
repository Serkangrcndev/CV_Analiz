document.addEventListener("DOMContentLoaded", () => {
  const chartDataEl = document.getElementById("chart-data");
  if (!chartDataEl) return;

  const score = parseInt(chartDataEl.getAttribute("data-general") || "0", 10);
  const radarLabels = JSON.parse(chartDataEl.getAttribute("data-radar-labels") || "[]");
  const radarValues = JSON.parse(chartDataEl.getAttribute("data-radar-values") || "[]");

  // 1. Draw Circular Score Gauge (Beautified with Outer Halo and Shadow Glow)
  const gaugeCanvas = document.getElementById("gauge-canvas");
  if (gaugeCanvas) {
    const ctx = gaugeCanvas.getContext("2d");
    const cx = gaugeCanvas.width / 2;
    const cy = gaugeCanvas.height / 2;
    const radius = 68;
    let currentPercent = 0;

    function animateGauge() {
      if (currentPercent > score) return;

      ctx.clearRect(0, 0, gaugeCanvas.width, gaugeCanvas.height);

      // Reset shadows
      ctx.shadowBlur = 0;

      // Draw subtle outer thin halo ring
      ctx.beginPath();
      ctx.arc(cx, cy, radius + 8, 0, Math.PI * 2);
      ctx.strokeStyle = "rgba(99, 102, 241, 0.08)";
      ctx.lineWidth = 1;
      ctx.stroke();

      // Background tracking ring
      ctx.beginPath();
      ctx.arc(cx, cy, radius, 0, Math.PI * 2);
      ctx.strokeStyle = "rgba(255, 255, 255, 0.04)";
      ctx.lineWidth = 10;
      ctx.stroke();

      // Active score arc
      ctx.beginPath();
      const startAngle = -Math.PI / 2;
      const endAngle = startAngle + (Math.PI * 2 * (currentPercent / 100));
      ctx.arc(cx, cy, radius, startAngle, endAngle);
      
      // Gradient stroke
      const gradient = ctx.createLinearGradient(0, 0, gaugeCanvas.width, gaugeCanvas.height);
      gradient.addColorStop(0, "#6366f1"); // Indigo
      gradient.addColorStop(0.5, "#8b5cf6"); // Violet
      gradient.addColorStop(1, "#ec4899"); // Pink
      
      ctx.strokeStyle = gradient;
      ctx.lineWidth = 10;
      ctx.lineCap = "round";

      // Glow effect on active arc
      ctx.shadowBlur = 12;
      ctx.shadowColor = "rgba(139, 92, 246, 0.45)";
      
      ctx.stroke();

      // Add small glowing dot at the head of the arc
      const headX = cx + radius * Math.cos(endAngle);
      const headY = cy + radius * Math.sin(endAngle);
      
      ctx.beginPath();
      ctx.arc(headX, headY, 5, 0, Math.PI * 2);
      ctx.fillStyle = "#ffffff";
      ctx.shadowBlur = 15;
      ctx.shadowColor = "#ec4899";
      ctx.fill();

      currentPercent++;
      requestAnimationFrame(animateGauge);
    }
    animateGauge();
  }

  // 2. Draw Custom Skill Radar Chart (Beautified with HUD Center Glow & Double Halo Nodes)
  const radarCanvas = document.getElementById("radar-canvas");
  if (radarCanvas) {
    const ctx = radarCanvas.getContext("2d");
    const cx = radarCanvas.width / 2;
    const cy = radarCanvas.height / 2;
    const maxRadius = 72;
    const numAxes = radarLabels.length;

    // Normalise values (cap count at 6 skills per category for 100% visualization)
    const normalizedValues = radarValues.map(val => {
      const maxSkillsInCat = 6;
      return Math.min(1.0, val / maxSkillsInCat);
    });

    let animScale = 0;

    function drawRadar() {
      ctx.clearRect(0, 0, radarCanvas.width, radarCanvas.height);
      ctx.shadowBlur = 0; // Reset shadows for grid rendering

      // Draw subtle HUD center background radial glow
      const radialGlow = ctx.createRadialGradient(cx, cy, 5, cx, cy, maxRadius);
      radialGlow.addColorStop(0, "rgba(99, 102, 241, 0.08)");
      radialGlow.addColorStop(1, "rgba(99, 102, 241, 0.0)");
      ctx.fillStyle = radialGlow;
      ctx.beginPath();
      ctx.arc(cx, cy, maxRadius, 0, Math.PI * 2);
      ctx.fill();

      // Draw grid webs (at 25%, 50%, 75%, 100% radius)
      const webLevels = [0.25, 0.5, 0.75, 1.0];
      ctx.strokeStyle = "rgba(99, 102, 241, 0.08)";
      ctx.lineWidth = 1;

      webLevels.forEach((level, index) => {
        const r = maxRadius * level;
        
        // Dotted grid lines for inner webs
        if (index < 3) {
          ctx.setLineDash([2, 3]);
        } else {
          ctx.setLineDash([]);
        }
        
        ctx.beginPath();
        for (let i = 0; i < numAxes; i++) {
          const angle = (i * 2 * Math.PI / numAxes) - Math.PI / 2;
          const x = cx + r * Math.cos(angle);
          const y = cy + r * Math.sin(angle);
          if (i === 0) ctx.moveTo(x, y);
          else ctx.lineTo(x, y);
        }
        ctx.closePath();
        ctx.stroke();
      });
      ctx.setLineDash([]); // Reset dash

      // Draw axis lines and labels
      ctx.strokeStyle = "rgba(255, 255, 255, 0.05)";
      ctx.fillStyle = "#9ca3af"; // text secondary
      ctx.font = "600 8.5px 'Outfit', sans-serif";
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";

      for (let i = 0; i < numAxes; i++) {
        const angle = (i * 2 * Math.PI / numAxes) - Math.PI / 2;
        const outerX = cx + maxRadius * Math.cos(angle);
        const outerY = cy + maxRadius * Math.sin(angle);

        // Draw axis line from center to outer ring
        ctx.beginPath();
        ctx.moveTo(cx, cy);
        ctx.lineTo(outerX, outerY);
        ctx.stroke();

        // Label offset adjustments to prevent overlaps
        const labelOffset = 14;
        const labelX = cx + (maxRadius + labelOffset) * Math.cos(angle);
        const labelY = cy + (maxRadius + labelOffset) * Math.sin(angle);

        // Text aligning adjustments based on position
        if (Math.cos(angle) < -0.1) ctx.textAlign = "right";
        else if (Math.cos(angle) > 0.1) ctx.textAlign = "left";
        else ctx.textAlign = "center";

        if (Math.sin(angle) < -0.1) ctx.textBaseline = "bottom";
        else if (Math.sin(angle) > 0.1) ctx.textBaseline = "top";
        else ctx.textBaseline = "middle";

        ctx.fillText(radarLabels[i], labelX, labelY);
      }

      // Draw candidate skill profile web
      ctx.beginPath();
      for (let i = 0; i < numAxes; i++) {
        const angle = (i * 2 * Math.PI / numAxes) - Math.PI / 2;
        const val = normalizedValues[i] * animScale;
        const r = maxRadius * Math.max(0.08, val);
        const x = cx + r * Math.cos(angle);
        const y = cy + r * Math.sin(angle);
        if (i === 0) ctx.moveTo(x, y);
        else ctx.lineTo(x, y);
      }
      ctx.closePath();

      // Web fill (Indigo-violet gradient with transparency)
      ctx.fillStyle = "rgba(99, 102, 241, 0.22)";
      ctx.fill();

      // Web border (Indigo glowing stroke)
      ctx.strokeStyle = "rgba(99, 102, 241, 0.85)";
      ctx.lineWidth = 2;
      ctx.shadowBlur = 10;
      ctx.shadowColor = "rgba(99, 102, 241, 0.5)";
      ctx.stroke();
      ctx.shadowBlur = 0; // Reset shadow

      // Draw double halo data point circles
      for (let i = 0; i < numAxes; i++) {
        const angle = (i * 2 * Math.PI / numAxes) - Math.PI / 2;
        const val = normalizedValues[i] * animScale;
        const r = maxRadius * Math.max(0.08, val);
        const x = cx + r * Math.cos(angle);
        const y = cy + r * Math.sin(angle);

        // Outer halo
        ctx.beginPath();
        ctx.arc(x, y, 6, 0, 2 * Math.PI);
        ctx.fillStyle = "rgba(168, 85, 247, 0.25)";
        ctx.fill();

        // Inner solid core
        ctx.beginPath();
        ctx.arc(x, y, 3, 0, 2 * Math.PI);
        ctx.fillStyle = "#ffffff";
        ctx.strokeStyle = "rgba(168, 85, 247, 1)";
        ctx.lineWidth = 1.5;
        ctx.fill();
        ctx.stroke();
      }

      if (animScale < 1.0) {
        animScale += 0.04;
        requestAnimationFrame(drawRadar);
      }
    }
    drawRadar();
  }
});
