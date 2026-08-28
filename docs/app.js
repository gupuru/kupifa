(() => {
  const bytes = document.getElementById("bytes");
  if (bytes) {
    bytes.textContent = "0";
  }

  const nav = document.querySelector(".nav");
  const onScroll = () => {
    nav?.classList.toggle("is-scrolled", window.scrollY > 8);
  };
  onScroll();
  window.addEventListener("scroll", onScroll, { passive: true });

  const modes = document.querySelectorAll(".panel .mode");
  modes.forEach((button) => {
    button.addEventListener("click", () => {
      modes.forEach((item) => item.classList.remove("is-on"));
      button.classList.add("is-on");
    });
  });

  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (!reduceMotion && "IntersectionObserver" in window) {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("reveal");
            observer.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.16 }
    );
    document.querySelectorAll(".will-reveal").forEach((el) => {
      observer.observe(el);
    });
  }
})();
