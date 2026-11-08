(function () {
  const Hooks = {};

  Hooks.GlobeDrag = {
    mounted() {
      this.dragging = false;
      this.moved = false;
      this.startX = 0;
      this.startY = 0;

      const svg = this.el.querySelector("svg");
      if (!svg) return;

      const centerX = parseFloat(this.el.dataset.centerX || "250");
      const centerY = parseFloat(this.el.dataset.centerY || "250");

      this.onPointerDown = (e) => {
        this.dragging = true;
        this.moved = false;
        this.startX = e.clientX;
        this.startY = e.clientY;
      };

      this.onPointerMove = (e) => {
        if (!this.dragging) return;
        const dx = e.clientX - this.startX;
        const dy = e.clientY - this.startY;
        if (Math.abs(dx) > 12 || Math.abs(dy) > 12) {
          this.moved = true;
          this.startX = e.clientX;
          this.startY = e.clientY;
          this.pushEvent("rotate_camera", {
            dlat: (dy * 0.35).toFixed(2),
            dlon: (-dx * 0.35).toFixed(2)
          });
        }
      };

      this.onPointerUp = () => {
        this.dragging = false;
      };

      this.onClick = (e) => {
        if (this.moved) return;
        const rect = svg.getBoundingClientRect();
        const scaleX = (svg.viewBox.baseVal.width || 500) / rect.width;
        const scaleY = (svg.viewBox.baseVal.height || 500) / rect.height;
        const clickX = (e.clientX - rect.left) * scaleX - centerX;
        const clickY = (e.clientY - rect.top) * scaleY - centerY;
        this.pushEvent("globe_click", {
          offset_x: clickX.toFixed(2),
          offset_y: clickY.toFixed(2)
        });
      };

      svg.addEventListener("pointerdown", this.onPointerDown);
      window.addEventListener("pointermove", this.onPointerMove);
      window.addEventListener("pointerup", this.onPointerUp);
      svg.addEventListener("click", this.onClick);
    },

    destroyed() {
      window.removeEventListener("pointermove", this.onPointerMove);
      window.removeEventListener("pointerup", this.onPointerUp);
    }
  };

  const csrfMeta = document.querySelector("meta[name='csrf-token']");
  const csrfToken = csrfMeta ? csrfMeta.getAttribute("content") : "";

  if (window.Phoenix && window.LiveView) {
    const liveSocket = new window.LiveView.LiveSocket("/live", window.Phoenix.Socket, {
      longPollFallbackMs: 2500,
      params: { _csrf_token: csrfToken },
      hooks: Hooks
    });
    liveSocket.connect();
    window.liveSocket = liveSocket;
  }
})();
