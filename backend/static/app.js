const api = {
  reports: "/api/reports",
  submit: "/api/reports/submit",
  scorecards: "/api/scorecards",
  hotspots: "/api/analysis/hotspots",
  nightly: "/api/analysis/trigger-nightly"
};

const districts = [
  ["Kathmandu", 27.7172, 85.3240],
  ["Lalitpur", 27.6588, 85.3247],
  ["Bhaktapur", 27.6710, 85.4298],
  ["Kaski", 28.2096, 83.9856],
  ["Morang", 26.4525, 87.2718],
  ["Parsa", 27.0104, 84.8774],
  ["Chitwan", 27.5291, 84.3542],
  ["Rupandehi", 27.5065, 83.4377],
  ["Banke", 28.0500, 81.6167],
  ["Kailali", 28.6833, 80.6000]
];

const institutions = [
  "Malpot (Land Revenue)",
  "Yatayat (Transport Management)",
  "Nepal Police Office",
  "Customs Department",
  "Internal Revenue Office",
  "District Administration Office",
  "Municipality Ward Office",
  "Public Procurement Office"
];

function $(selector, root = document) {
  return root.querySelector(selector);
}

function $all(selector, root = document) {
  return [...root.querySelectorAll(selector)];
}

function fmtMoney(value) {
  return "Rs. " + Number(value || 0).toLocaleString("en-IN");
}

function fmtDate(ts) {
  if (!ts) return "Not recorded";
  return new Date(ts * 1000).toLocaleString();
}

function confidenceClass(score) {
  if (score >= 0.75) return "good";
  if (score >= 0.45) return "warn";
  return "bad";
}

async function getJson(url, options) {
  const res = await fetch(url, options);
  if (!res.ok) {
    const text = await res.text();
    throw new Error(text || `Request failed: ${res.status}`);
  }
  return res.json();
}

function setActiveNav() {
  const page = document.body.dataset.page;
  $all("[data-nav]").forEach((a) => a.classList.toggle("active", a.dataset.nav === page));
}

function toast(message, type = "ok") {
  let wrap = $(".toast-wrap");
  if (!wrap) {
    wrap = document.createElement("div");
    wrap.className = "toast-wrap";
    document.body.appendChild(wrap);
  }
  const item = document.createElement("div");
  item.className = `toast ${type}`;
  item.textContent = message;
  wrap.appendChild(item);
  setTimeout(() => item.remove(), 3400);
}

function reportCard(report) {
  const card = document.createElement("article");
  card.className = "report-card";
  const initials = (report.district || "NP").slice(0, 2).toUpperCase();
  const district = escapeHtml(report.district || "Unknown district");
  const institution = escapeHtml(report.institution || "Unknown institution");
  const status = escapeHtml(report.status || "pending");
  
  let mediaHtml = "";
  if (report.evidencePhoto || report.evidenceAudio || report.evidenceVideo) {
    mediaHtml += `<div class="feed-evidence-section">`;
    if (report.evidencePhoto) {
      mediaHtml += `<img src="${escapeHtml(report.evidencePhoto)}" class="feed-media-photo" alt="Evidence Photo">`;
    }
    if (report.evidenceAudio) {
      mediaHtml += `<audio controls src="${escapeHtml(report.evidenceAudio)}" class="feed-media-audio"></audio>`;
    }
    if (report.evidenceVideo) {
      mediaHtml += `<video controls src="${escapeHtml(report.evidenceVideo)}" class="feed-media-video"></video>`;
    }
    mediaHtml += `</div>`;
  }

  const hasEv = report.evidenceUrl || report.evidencePhoto || report.evidenceAudio || report.evidenceVideo;

  card.innerHTML = `
    <div class="row between">
      <div class="row" style="gap:12px;align-items:flex-start">
        <div class="anon-avatar">${escapeHtml(initials)}</div>
        <div>
          <p class="eyebrow">Anonymous citizen - ${district}</p>
          <h3>${institution}</h3>
        </div>
      </div>
      <span class="pill ${confidenceClass(report.confidence)}">${Math.round((report.confidence || 0) * 100)}% confidence</span>
    </div>
    <p>${escapeHtml(report.description || "")}</p>
    ${mediaHtml}
    <div class="meta">
      <span class="tag">CIVIC SIGNAL</span>
      <span>${fmtMoney(report.bribeAmount)}</span>
      <span>${status}</span>
      <span>${fmtDate(report.timestamp)}</span>
    </div>
    <div class="meter"><span style="width:${Math.round((report.confidence || 0) * 100)}%"></span></div>
    <div class="row between">
      <button class="btn small upvote" data-id="${report.id}">Upvote (${report.upvotes || 0})</button>
      <span class="pill ${hasEv ? "good" : "warn"}">${hasEv ? "Evidence Attached" : "No Evidence"}</span>
    </div>
  `;
  return card;
}

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (ch) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#039;"
  }[ch]));
}

async function loadHome() {
  const [reports, scorecards, hotspots] = await Promise.all([
    getJson(api.reports),
    getJson(api.scorecards),
    getJson(api.hotspots)
  ]);
  const totalBribes = reports.reduce((sum, r) => sum + Number(r.bribeAmount || 0), 0);
  $("#stat-reports").textContent = reports.length;
  $("#stat-institutions").textContent = scorecards.length;
  $("#stat-bribes").textContent = totalBribes.toLocaleString("en-IN");
  $("#stat-hotspots").textContent = hotspots.length;
  drawMiniMap($("#mini-map"), reports, hotspots);

  const list = $("#recent-reports");
  reports.slice(0, 3).forEach((report) => list.appendChild(reportCard(report)));
  wireUpvotes(list);
}

async function loadFeed() {
  const reports = await getJson(api.reports);
  const list = $("#report-list");
  const search = $("#search");
  const district = $("#district-filter");

  fillDistrictOptions(district);

  function render() {
    const q = search.value.trim().toLowerCase();
    const d = district.value;
    list.innerHTML = "";
    reports
      .filter((r) => !d || r.district === d)
      .filter((r) => !q || `${r.institution} ${r.description} ${r.district}`.toLowerCase().includes(q))
      .forEach((report) => list.appendChild(reportCard(report)));
    wireUpvotes(list);
  }
  search.addEventListener("input", render);
  district.addEventListener("change", render);
  render();
}

function wireUpvotes(root) {
  $all(".upvote", root).forEach((btn) => {
    btn.addEventListener("click", async () => {
      btn.disabled = true;
      try {
        const data = await getJson(`/api/reports/${btn.dataset.id}/upvote`, { method: "POST" });
        btn.textContent = `Upvote (${data.upvotes})`;
        toast(data.escalated ? "Report crossed escalation threshold." : "Upvote recorded.");
      } catch (err) {
        toast("Could not upvote report.", "bad");
      } finally {
        btn.disabled = false;
      }
    });
  });
}

function fillDistrictOptions(select) {
  if (!select) return;
  districts.forEach(([name]) => {
    const opt = document.createElement("option");
    opt.value = name;
    opt.textContent = name;
    select.appendChild(opt);
  });
}

function fillSelect(select, values) {
  values.forEach((value) => {
    const opt = document.createElement("option");
    opt.value = value;
    opt.textContent = value;
    select.appendChild(opt);
  });
}

async function loadSubmit() {
  fillSelect($("#institution"), institutions);
  fillDistrictOptions($("#district"));
  
  $("#district").addEventListener("change", (event) => {
    const found = districts.find(([name]) => name === event.target.value);
    if (found) {
      $("#lat").value = found[1];
      $("#lng").value = found[2];
    }
  });
  $("#district").dispatchEvent(new Event("change"));

  const steps = $all(".wizard-step");
  $all("input, select, textarea", $("#report-form")).forEach((field, index) => {
    field.addEventListener("focus", () => {
      steps.forEach((step, stepIndex) => step.classList.toggle("active", stepIndex === Math.min(3, Math.floor(index / 2))));
    });
  });

  // Local media capture state.
  let activeStream = null;
  let mediaRecorder = null;
  let recordedChunks = [];
  let recordTimerInterval = null;
  
  const livePanel = $("#live-media-panel");
  const cameraChannel = $("#camera-capture-channel");
  const audioChannel = $("#audio-record-channel");
  const videoChannel = $("#video-capture-channel");
  const previewsContainer = $("#media-previews");
  
  // Hidden values sent with the report payload.
  const photoInput = $("#evidencePhoto");
  const audioInput = $("#evidenceAudio");
  const videoInput = $("#evidenceVideo");
  
  // Native file inputs used as a fallback for direct uploads.
  const photoFileInput = $("#photo-file-input");
  const audioFileInput = $("#audio-file-input");
  const videoFileInput = $("#video-file-input");

  // De-activate and clean active hardware streams safely
  function stopActiveStreams() {
    if (activeStream) {
      activeStream.getTracks().forEach(track => track.stop());
      activeStream = null;
    }
    if (recordTimerInterval) {
      clearInterval(recordTimerInterval);
      recordTimerInterval = null;
    }
    mediaRecorder = null;
    recordedChunks = [];
    
    // UI state reset
    cameraChannel.classList.add("hidden");
    audioChannel.classList.add("hidden");
    videoChannel.classList.add("hidden");
    livePanel.classList.add("hidden");
    $all(".evidence-btn").forEach(btn => btn.classList.remove("active"));
  }

  // Upload raw base64 data to FastAPI
  async function uploadBase64(base64Data, filename) {
    try {
      const res = await getJson("/api/reports/upload-base64", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ filename, base64_data: base64Data })
      });
      return res.url;
    } catch (e) {
      console.error(e);
      toast("Secure upload failed. Please try again.", "bad");
      return null;
    }
  }

  // Render preview chips of attached files
  function addMediaPreview(type, url, name) {
    // Single media slot of each type allowed
    const existing = previewsContainer.querySelector(`[data-media-type="${type}"]`);
    if (existing) existing.remove();
    
    const card = document.createElement("div");
    card.className = "preview-card";
    card.dataset.mediaType = type;
    
    let previewElement = "";
    if (type === "photo") {
      previewElement = `<img src="${url}" class="preview-thumb">`;
      photoInput.value = url;
    } else if (type === "audio") {
      previewElement = `
        <div class="preview-player-wrap">
          <audio controls src="${url}"></audio>
        </div>
      `;
      audioInput.value = url;
    } else if (type === "video") {
      previewElement = `
        <div class="preview-player-wrap">
          <video controls src="${url}" style="width:100px;height:60px;border-radius:6px;background:#000"></video>
        </div>
      `;
      videoInput.value = url;
    }
    
    card.innerHTML = `
      <div class="preview-info">
        ${type === "photo" ? previewElement : '<div class="preview-icon-placeholder">' + (type === "audio" ? "🎙️" : "🎥") + '</div>'}
        <div class="preview-text">
          <span class="type">${type} evidence</span>
          <span class="name">${name.length > 20 ? name.slice(0, 17) + "..." : name}</span>
        </div>
        ${type !== "photo" ? previewElement : ""}
      </div>
      <button type="button" class="preview-remove-btn">&times;</button>
    `;
    
    card.querySelector(".preview-remove-btn").addEventListener("click", () => {
      card.remove();
      if (type === "photo") photoInput.value = "";
      if (type === "audio") audioInput.value = "";
      if (type === "video") videoInput.value = "";
      toast(`${type} evidence removed from draft.`);
    });
    
    previewsContainer.appendChild(card);
    toast(`${type} evidence attached!`);
  }

  // Read local file as Base64 to pipe to our upload engine
  async function handleFileSelect(file, type) {
    if (!file) return;
    const reader = new FileReader();
    reader.onload = async (e) => {
      const base64Data = e.target.result;
      const uploadedUrl = await uploadBase64(base64Data, file.name);
      if (uploadedUrl) {
        addMediaPreview(type, uploadedUrl, file.name);
      }
    };
    reader.readAsDataURL(file);
  }

  // Bind fallback file-upload buttons
  $("#btn-upload-photo-file").addEventListener("click", () => photoFileInput.click());
  $("#btn-upload-audio-file").addEventListener("click", () => audioFileInput.click());
  $("#btn-upload-video-file").addEventListener("click", () => videoFileInput.click());

  photoFileInput.addEventListener("change", (e) => {
    handleFileSelect(e.target.files[0], "photo");
    stopActiveStreams();
  });
  audioFileInput.addEventListener("change", (e) => {
    handleFileSelect(e.target.files[0], "audio");
    stopActiveStreams();
  });
  videoFileInput.addEventListener("change", (e) => {
    handleFileSelect(e.target.files[0], "video");
    stopActiveStreams();
  });

  // 1. Direct WebCam Photo Capture
  $("#btn-photo-mode").addEventListener("click", async () => {
    stopActiveStreams();
    $("#btn-photo-mode").classList.add("active");
    livePanel.classList.remove("hidden");
    cameraChannel.classList.remove("hidden");
    
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: "environment" }, audio: false });
      activeStream = stream;
      $("#webcam-preview").srcObject = stream;
    } catch (e) {
      console.error(e);
      toast("Could not start camera. Choose File fallback instead.", "bad");
    }
  });

  $("#btn-snap-photo").addEventListener("click", async () => {
    const video = $("#webcam-preview");
    const canvas = $("#photo-canvas");
    if (!activeStream) {
      toast("Camera stream is offline.", "bad");
      return;
    }
    
    const ctx = canvas.getContext("2d");
    canvas.width = video.videoWidth || 640;
    canvas.height = video.videoHeight || 480;
    
    // Mirroring horizontal to match selfie layout
    ctx.translate(canvas.width, 0);
    ctx.scale(-1, 1);
    ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
    
    const base64Data = canvas.toDataURL("image/jpeg");
    const name = `capture_${Date.now()}.jpg`;
    
    const url = await uploadBase64(base64Data, name);
    if (url) {
      addMediaPreview("photo", url, name);
    }
    stopActiveStreams();
  });

  $("#btn-cancel-camera").addEventListener("click", stopActiveStreams);

  // 2. Direct Voice/Audio Recorder
  $("#btn-audio-mode").addEventListener("click", () => {
    stopActiveStreams();
    $("#btn-audio-mode").classList.add("active");
    livePanel.classList.remove("hidden");
    audioChannel.classList.remove("hidden");
    $("#audio-record-status").textContent = "Microphone Ready";
    $("#audio-timer").textContent = "00:00";
    
    $("#btn-start-audio").disabled = false;
    $("#btn-stop-audio").disabled = true;
  });

  $("#btn-start-audio").addEventListener("click", async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      activeStream = stream;
      
      mediaRecorder = new MediaRecorder(stream);
      recordedChunks = [];
      
      mediaRecorder.ondataavailable = (e) => {
        if (e.data.size > 0) recordedChunks.push(e.data);
      };
      
      mediaRecorder.onstop = async () => {
        const audioBlob = new Blob(recordedChunks, { type: "audio/webm" });
        const reader = new FileReader();
        reader.onload = async (e) => {
          const base64Data = e.target.result;
          const name = `recording_${Date.now()}.webm`;
          const url = await uploadBase64(base64Data, name);
          if (url) {
            addMediaPreview("audio", url, name);
          }
        };
        reader.readAsDataURL(audioBlob);
      };
      
      mediaRecorder.start();
      $("#audio-record-status").textContent = "🎙️ RECORDING VOICE LIVE";
      $("#btn-start-audio").disabled = true;
      $("#btn-stop-audio").disabled = false;
      
      let sec = 0;
      recordTimerInterval = setInterval(() => {
        sec++;
        const m = String(Math.floor(sec / 60)).padStart(2, '0');
        const s = String(sec % 60).padStart(2, '0');
        $("#audio-timer").textContent = `${m}:${s}`;
      }, 1000);
      
    } catch (e) {
      console.error(e);
      toast("Microphone access denied or unavailable.", "bad");
    }
  });

  $("#btn-stop-audio").addEventListener("click", () => {
    if (mediaRecorder && mediaRecorder.state !== "inactive") {
      mediaRecorder.stop();
    }
    stopActiveStreams();
  });

  $("#btn-cancel-audio").addEventListener("click", stopActiveStreams);

  // 3. Direct Video Recorder
  $("#btn-video-mode").addEventListener("click", async () => {
    stopActiveStreams();
    $("#btn-video-mode").classList.add("active");
    livePanel.classList.remove("hidden");
    videoChannel.classList.remove("hidden");
    
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ video: true, audio: true });
      activeStream = stream;
      $("#video-preview").srcObject = stream;
      
      $("#btn-start-video-rec").disabled = false;
      $("#btn-stop-video-rec").disabled = true;
    } catch (e) {
      console.error(e);
      toast("Webcam access denied or unavailable.", "bad");
    }
  });

  $("#btn-start-video-rec").addEventListener("click", () => {
    if (!activeStream) return;
    
    mediaRecorder = new MediaRecorder(activeStream);
    recordedChunks = [];
    
    mediaRecorder.ondataavailable = (e) => {
      if (e.data.size > 0) recordedChunks.push(e.data);
    };
    
    mediaRecorder.onstop = async () => {
      const videoBlob = new Blob(recordedChunks, { type: "video/webm" });
      const reader = new FileReader();
      reader.onload = async (e) => {
        const base64Data = e.target.result;
        const name = `video_${Date.now()}.webm`;
        const url = await uploadBase64(base64Data, name);
        if (url) {
          addMediaPreview("video", url, name);
        }
      };
      reader.readAsDataURL(videoBlob);
    };
    
    mediaRecorder.start();
    $("#btn-start-video-rec").disabled = true;
    $("#btn-stop-video-rec").disabled = false;
    $("#btn-start-video-rec").textContent = "🔴 Recording...";
    toast("Recording started.");
  });

  $("#btn-stop-video-rec").addEventListener("click", () => {
    if (mediaRecorder && mediaRecorder.state !== "inactive") {
      mediaRecorder.stop();
    }
    $("#btn-start-video-rec").textContent = "Start Rec";
    stopActiveStreams();
  });

  $("#btn-cancel-video").addEventListener("click", stopActiveStreams);

  // Submit handler
  $("#report-form").addEventListener("submit", async (event) => {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    
    const finalPhoto = photoInput.value || "";
    const finalAudio = audioInput.value || "";
    const finalVideo = videoInput.value || "";
    const finalEv = finalPhoto || finalAudio || finalVideo || "";
    
    const payload = {
      institution: form.get("institution"),
      district: form.get("district"),
      description: form.get("description"),
      bribeAmount: Number(form.get("bribeAmount") || 0),
      evidenceUrl: finalEv,
      evidencePhoto: finalPhoto,
      evidenceAudio: finalAudio,
      evidenceVideo: finalVideo,
      lat: Number(form.get("lat")),
      lng: Number(form.get("lng")),
      isAnonymous: true
    };
    
    const button = $("button[type=submit]", event.currentTarget);
    button.disabled = true;
    button.textContent = "Submitting protected report...";
    
    try {
      const result = await getJson(api.submit, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload)
      });
      
      $("#result").classList.remove("hidden");
      $("#result").innerHTML = `
        <h3 style="font-family: Fraunces, Georgia, serif; color: var(--green); margin-bottom: 6px">✓ Report Encrypted & Filed</h3>
        <p><b>Tracking ID:</b> <code style="background: rgba(0,0,0,0.05); padding: 2px 6px; border-radius: 4px">${result.id}</code></p>
        <p><b>AI Status:</b> ${result.status === "flagged" ? "⚠️ flagged (potential duplicate)" : "🟢 validated & recorded"}</p>
        <p><b>Credibility Rating:</b> <b>${Math.round(result.confidence * 100)}% confidence</b></p>
        <p style="margin-top: 8px; font-size: 13px; color: var(--soft)">${result.message}</p>
      `;
      
      event.currentTarget.reset();
      previewsContainer.innerHTML = "";
      photoInput.value = "";
      audioInput.value = "";
      videoInput.value = "";
      stopActiveStreams();
      
      toast("Anonymous report filed successfully!");
    } catch (err) {
      console.error(err);
      toast("Submission failed. Check required fields.", "bad");
    } finally {
      button.disabled = false;
      button.textContent = "Submit Protected Report";
    }
  });
}

async function loadHeatmap() {
  await getJson(api.nightly, { method: "POST" });
  const [reports, hotspots] = await Promise.all([getJson(api.reports), getJson(api.hotspots)]);
  drawMap($("#map"), reports, hotspots);
  const list = $("#hotspot-list");
  hotspots.forEach((h) => {
    const item = document.createElement("article");
    item.className = "mini-card";
    item.innerHTML = `<h3>${escapeHtml(h.label || "Hotspot")}</h3><p>Lat ${h.lat.toFixed(3)}, Lng ${h.lng.toFixed(3)}</p>`;
    list.appendChild(item);
  });
}

function getFeatureReportData(feature, reports) {
  // Extract all string properties of the vector feature to scan for district name matches
  const props = [];
  feature.forEachProperty((val, key) => {
    if (typeof val === 'string') props.push(val.toLowerCase().trim());
  });
  
  // Find reports matching this territory
  const matchedReports = reports.filter(r => {
    const dist = (r.district || "").toLowerCase().trim();
    return props.some(p => p.includes(dist) || dist.includes(p));
  });
  
  const totalBribes = matchedReports.reduce((sum, r) => sum + (r.bribeAmount || 0), 0);
  
  // Fetch name representing the territory
  const name = feature.getProperty('name') || 
               feature.getProperty('Province') || 
               feature.getProperty('PR_NAME') || 
               feature.getProperty('DISTRICT') || 
               feature.getProperty('NAME_3') || 
               "Nepal Territory";
               
  return {
    count: matchedReports.length,
    bribes: totalBribes,
    name: name
  };
}

function drawMap(root, reports, hotspots, mini = false) {
  if (!root) return;
  
  const drawFallback = () => drawSvgFallbackMap(root, reports, hotspots, mini);
  
  loadGoogleMapsScript(() => {
    root.innerHTML = ""; // Clear loader placeholder
    
    // Tightly centered on the geographic heart of Nepal
    const centerLatLng = { lat: 28.3949, lng: 84.1240 };
    
    // Strict bounding coordinates centered on Nepal
    const nepalBounds = {
      north: 30.6,
      south: 25.8,
      west: 80.0,
      east: 88.6
    };
    
    // Clean, focused Google Map style
    const map = new google.maps.Map(root, {
      center: centerLatLng,
      zoom: mini ? 5.8 : 7.4,
      restriction: {
        latLngBounds: nepalBounds,
        strictBounds: true
      },
      styles: [
        { "featureType": "all", "elementType": "labels", "stylers": [{ "visibility": "off" }] },
        { "featureType": "road", "stylers": [{ "visibility": "off" }] },
        { "featureType": "poi", "stylers": [{ "visibility": "off" }] },
        { "featureType": "transit", "stylers": [{ "visibility": "off" }] },
        { "featureType": "water", "elementType": "geometry", "stylers": [{ "color": "#cbd9ea" }] },
        { "featureType": "landscape", "elementType": "geometry", "stylers": [{ "color": "#f5f6f8" }] }
      ],
      mapTypeId: 'roadmap',
      disableDefaultUI: mini,
      zoomControl: !mini,
      streetViewControl: false,
      mapTypeControl: false,
      fullscreenControl: !mini
    });

    // Load dynamic GeoJSON boundaries (bold borders & distinct heat colors)
    try {
      map.data.loadGeoJson('/static/provinces.geojson', null, () => {
        // Styled dynamically once loaded
        map.data.setStyle(feature => {
          const data = getFeatureReportData(feature, reports);
          let fillColor = "rgba(79, 181, 255, 0.12)"; // Base cool translucent blue
          
          if (data.count >= 3) {
            fillColor = "rgba(217, 74, 74, 0.50)"; // Hot Red
          } else if (data.count === 2) {
            fillColor = "rgba(240, 160, 58, 0.40)"; // Warning Orange
          } else if (data.count === 1) {
            fillColor = "rgba(24, 163, 99, 0.30)"; // Low density Green
          } else {
            // Assign slightly varying distinct colors to districts/provinces for visual pop
            const id = feature.getProperty('id') || feature.getProperty('FID') || Math.floor(Math.random() * 5);
            const distinctColors = [
              "rgba(79, 181, 255, 0.10)",
              "rgba(110, 231, 245, 0.10)",
              "rgba(123, 95, 214, 0.08)",
              "rgba(240, 160, 58, 0.08)",
              "rgba(24, 163, 99, 0.08)"
            ];
            fillColor = distinctColors[id % distinctColors.length];
          }
          
          return {
            fillColor: fillColor,
            fillOpacity: 0.65,
            strokeColor: "#273866", // Bold navy boundary stroke
            strokeWeight: 2,       // Bold boundary!
            visible: true
          };
        });
      });
      
      // Interactive vector clicks (Auto-Zoom, Pan, and Area details window)
      if (!mini) {
        map.data.addListener('click', event => {
          const feature = event.feature;
          const data = getFeatureReportData(feature, reports);
          
          map.panTo(event.latLng);
          map.setZoom(8.4);
          
          const content = `
            <div style="font-family:'Outfit',sans-serif; padding:10px; color:#11152b; max-width:250px">
              <h3 style="margin:0 0 4px;font-family:'Fraunces',serif;font-size:18px;color:#273866">${escapeHtml(data.name)}</h3>
              <p style="margin:0 0 10px;font-size:10px;color:#737891;font-weight:800;letter-spacing:0.06em;text-transform:uppercase">Civic Signal Territory</p>
              
              <div style="display:grid; grid-template-columns:1fr 1fr; gap:8px; margin-bottom:10px; background:#f5f6f9; padding:8px; border-radius:8px; border:1px solid #e1e4ea">
                <div>
                  <small style="display:block;color:#8a8fa4;font-size:9px;font-weight:800;text-transform:uppercase">Reports</small>
                  <strong style="font-size:15px;color:#273866">${data.count} cases</strong>
                </div>
                <div>
                  <small style="display:block;color:#8a8fa4;font-size:9px;font-weight:800;text-transform:uppercase">Bribes Sum</small>
                  <strong style="font-size:14px;color:#d94a4a">Rs. ${data.bribes.toLocaleString("en-IN")}</strong>
                </div>
              </div>
              
              <p style="margin:0;font-size:12px;color:#4f5873;line-height:1.4">
                ${data.count > 0 
                  ? "Whistleblower evidence successfully maps active transparency and administrative risk within this sector."
                  : "No high-confidence reports submitted for this territory yet. Regional transparency remains solid."
                }
              </p>
            </div>
          `;
          
          const info = new google.maps.InfoWindow({
            content: content,
            position: event.latLng
          });
          info.open(map);
        });
      }
    } catch (err) {
      console.error("GeoJSON boundaries failed to load.", err);
    }

    // 1. Concentric Circle Thermal Heatmap (100% Stable Core - Zero Dependencies)
    reports.forEach(r => {
      const baseRadius = Math.max(9000, Math.min(38000, (r.bribeAmount || 0) * 1.5));
      const heatColor = r.confidence >= 0.75 ? '#18a363' : (r.confidence >= 0.45 ? '#f0a03a' : '#d94a4a');
      
      const rings = [
        { radius: baseRadius * 2.4, opacity: 0.05 }, 
        { radius: baseRadius * 1.4, opacity: 0.16 }, 
        { radius: baseRadius * 0.7, opacity: 0.38 }  
      ];
      
      rings.forEach(ring => {
        new google.maps.Circle({
          strokeColor: 'none',
          strokeOpacity: 0,
          fillColor: heatColor,
          fillOpacity: ring.opacity,
          map: map,
          center: { lat: r.lat, lng: r.lng },
          radius: ring.radius,
          clickable: false
        });
      });
    });

    // 2. Custom core circular markers (interactive pins)
    reports.forEach(r => {
      const pinColor = r.confidence >= 0.75 ? '#18a363' : (r.confidence >= 0.45 ? '#f0a03a' : '#d94a4a');
      const marker = new google.maps.Marker({
        position: { lat: r.lat, lng: r.lng },
        map: map,
        title: r.institution,
        icon: {
          path: google.maps.SymbolPath.CIRCLE,
          scale: mini ? 3.5 : 5,
          fillColor: pinColor,
          fillOpacity: 0.95,
          strokeColor: '#ffffff',
          strokeWeight: 1.2
        }
      });

      if (!mini) {
        const info = new google.maps.InfoWindow({
          content: `
            <div style="font-family:'Outfit',sans-serif; padding:8px; color:#11152b; max-width:240px">
              <h4 style="margin:0 0 4px;font-family:'Fraunces',serif;font-size:15px;color:#273866">${escapeHtml(r.institution)}</h4>
              <p style="margin:0 0 6px;font-size:11px;color:#737891;font-weight:700">Anonymous citizen - ${escapeHtml(r.district)}</p>
              <p style="margin:0 0 6px;font-size:12.5px;line-height:1.4;color:#4f5873">${escapeHtml(r.description.slice(0, 100))}...</p>
              <strong style="color:#d94a4a;font-size:13px">Rs. ${r.bribeAmount.toLocaleString("en-IN")} bribe</strong>
            </div>
          `
        });

        marker.addListener("click", () => {
          info.open(map, marker);
        });
      }
    });
  }, drawFallback);
}

function drawMiniMap(root, reports, hotspots) {
  drawMap(root, reports, hotspots, true);
}

async function loadScorecards() {
  await getJson(api.nightly, { method: "POST" });
  const cards = await getJson(api.scorecards);
  const list = $("#scorecard-list");
  cards
    .sort((a, b) => b.risk_score - a.risk_score)
    .forEach((card) => {
      const item = document.createElement("article");
      item.className = "score-card";
      item.innerHTML = `
        <div class="row between">
          <div>
            <p class="eyebrow">${card.risk_level} risk</p>
            <h3>${escapeHtml(card.institution)}</h3>
          </div>
          <span class="score">${card.risk_score}</span>
        </div>
        <div class="meter"><span style="width:${card.risk_score}%"></span></div>
        <div class="meta">
          <span>${card.total_reports} reports</span>
          <span>${fmtMoney(card.bribes_sum)}</span>
        </div>
      `;
      list.appendChild(item);
    });
}

function loadCiaa() {
  $all(".check-item").forEach((item) => {
    item.addEventListener("click", () => item.classList.toggle("checked"));
  });
}

async function loadAdmin() {
  await getJson(api.nightly, { method: "POST" });
  const [reports, hotspots] = await Promise.all([getJson(api.reports), getJson(api.hotspots)]);
  const avg = reports.length
    ? reports.reduce((sum, report) => sum + Number(report.confidence || 0), 0) / reports.length
    : 0;
  $("#admin-reports").textContent = reports.length;
  $("#admin-confidence").textContent = `${Math.round(avg * 100)}%`;
  $("#admin-escalations").textContent = reports.filter((report) => Number(report.confidence || 0) >= 0.75).length;
  $("#admin-hotspots").textContent = hotspots.length;
  drawMap($("#admin-map"), reports, hotspots);
}

document.addEventListener("DOMContentLoaded", async () => {
  setActiveNav();
  try {
    const page = document.body.dataset.page;
    if (page === "home") await loadHome();
    if (page === "feed") await loadFeed();
    if (page === "submit") await loadSubmit();
    if (page === "heatmap") await loadHeatmap();
    if (page === "scorecards") await loadScorecards();
    if (page === "ciaa") loadCiaa();
    if (page === "admin") await loadAdmin();
  } catch (err) {
    console.error(err);
    toast("Backend is not reachable. Start FastAPI on port 8000.", "bad");
  }
});
