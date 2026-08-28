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

  const samples = {
    "文章を整える": {
      input: "明日の打ち合わせ、少し遅れそうです。先に資料だけ共有しておきます。",
      result: "明日の打ち合わせに少々遅れる見込みです。恐れ入りますが、先に資料のみ共有いたします。",
    },
    "返事作成": {
      input: "来週の火曜か水曜で、30分ほどお時間いただけますか。",
      result: "ご調整ありがとうございます。水曜 15:00 からであればお受けできます。",
    },
    "翻訳": {
      input: "Please find the attached deck for tomorrow's review.",
      result: "明日のレビュー用資料を添付いたします。ご確認ください。",
    },
  };
  const inputEl = document.querySelector(".ghost-input");
  const resultEl = document.querySelector(".result-card p:last-child");
  const modes = document.querySelectorAll(".panel .mode");
  modes.forEach((button) => {
    button.addEventListener("click", () => {
      modes.forEach((item) => item.classList.remove("is-on"));
      button.classList.add("is-on");
      const sample = samples[button.textContent.trim()];
      if (sample && inputEl && resultEl) {
        inputEl.textContent = sample.input;
        resultEl.textContent = sample.result;
      }
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
