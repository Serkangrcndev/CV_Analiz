document.addEventListener("DOMContentLoaded", () => {
  const dropZone = document.getElementById("drop-zone");
  const fileInput = document.getElementById("cv-file");
  const uploadForm = document.getElementById("upload-form");
  const loadingOverlay = document.getElementById("loading-overlay");

  if (!dropZone || !fileInput || !uploadForm) return;

  // Drag-and-drop listeners
  ["dragenter", "dragover"].forEach(eventName => {
    dropZone.addEventListener(eventName, (e) => {
      e.preventDefault();
      e.stopPropagation();
      dropZone.classList.add("dragover");
    }, false);
  });

  ["dragleave", "drop"].forEach(eventName => {
    dropZone.addEventListener(eventName, (e) => {
      e.preventDefault();
      e.stopPropagation();
      dropZone.classList.remove("dragover");
    }, false);
  });

  dropZone.addEventListener("drop", (e) => {
    const dt = e.dataTransfer;
    const files = dt.files;
    if (files.length > 0) {
      fileInput.files = files;
      handleUpload();
    }
  });

  fileInput.addEventListener("change", () => {
    if (fileInput.files.length > 0) {
      handleUpload();
    }
  });

  // Intercept zone click to trigger browse
  dropZone.addEventListener("click", (e) => {
    if (e.target.tagName !== "INPUT" && e.target.tagName !== "LABEL") {
      fileInput.click();
    }
  });

  function handleUpload() {
    const file = fileInput.files[0];
    if (!file) return;

    // Show loading overlay
    loadingOverlay.style.display = "flex";

    // Setup animated progress steps
    const steps = [
      { id: "step-parsing", delay: 0 },
      { id: "step-skills", delay: 800 },
      { id: "step-ats", delay: 1600 },
      { id: "step-matching", delay: 2400 },
      { id: "step-report", delay: 3200 }
    ];

    steps.forEach(step => {
      const el = document.getElementById(step.id);
      if (el) {
        el.className = "step";
        el.querySelector("i").className = "fa-regular fa-circle";
      }
    });

    // Run animation timeline
    steps.forEach(step => {
      setTimeout(() => {
        // Mark previous steps as completed
        steps.forEach(s => {
          if (s.delay < step.delay) {
            const prevEl = document.getElementById(s.id);
            if (prevEl && !prevEl.classList.contains("completed")) {
              prevEl.classList.remove("active");
              prevEl.classList.add("completed");
              prevEl.querySelector("i").className = "fa-solid fa-circle-check";
            }
          }
        });

        // Mark current step as active
        const curEl = document.getElementById(step.id);
        if (curEl) {
          curEl.classList.add("active");
          curEl.querySelector("i").className = "fa-solid fa-circle-notch fa-spin";
        }
      }, step.delay);
    });

    // Form data upload
    const formData = new FormData();
    formData.append("cv", file);

    const xhr = new XMLHttpRequest();
    xhr.open("POST", "/analyze", true);

    const startTime = Date.now();

    xhr.onload = function() {
      const endTime = Date.now();
      const duration = endTime - startTime;
      // We want to make sure the user sees all animation steps (takes ~4 seconds)
      const minDuration = 4200;
      const remainingTime = Math.max(0, minDuration - duration);

      setTimeout(() => {
        if (xhr.status === 200) {
          try {
            const response = JSON.parse(xhr.responseText);
            // Complete last step
            const lastStep = document.getElementById("step-report");
            if (lastStep) {
              lastStep.classList.remove("active");
              lastStep.classList.add("completed");
              lastStep.querySelector("i").className = "fa-solid fa-circle-check";
            }
            
            // Redirect to dashboard
            setTimeout(() => {
              window.location.href = response.redirect_url;
            }, 500);
          } catch(e) {
            showError("Failed to interpret analysis output. Please try again.");
          }
        } else {
          try {
            const response = JSON.parse(xhr.responseText);
            showError(response.error || "Analysis failed.");
          } catch(e) {
            showError("A connection error occurred. Check file format.");
          }
        }
      }, remainingTime);
    };

    xhr.onerror = function() {
      showError("A network error occurred while uploading. Please check local connectivity.");
    };

    xhr.send(formData);
  }

  function showError(msg) {
    loadingOverlay.style.display = "none";
    
    // Check if toast already exists
    let toast = document.getElementById("session-toast");
    if (!toast) {
      toast = document.createElement("div");
      toast.id = "session-toast";
      document.body.appendChild(toast);
    }
    toast.className = "toast-notification toast-error";
    toast.innerHTML = `
      <i class="fa-solid fa-circle-exclamation"></i>
      <span>${msg}</span>
      <button onclick="this.parentElement.remove()">&times;</button>
    `;

    setTimeout(() => {
      if (toast) toast.remove();
    }, 5000);
  }
});
