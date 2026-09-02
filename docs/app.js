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
    polish: {
      input: "明日の打ち合わせ、少し遅れそうです。先に資料だけ共有しておきます。",
      ja: "明日の打ち合わせ、少し遅れる予定です。先に資料だけ共有します。",
      en: "I'll be a little late to tomorrow's meeting. I'll share the materials first.",
    },
    reply: {
      input: "相手: 来週、火曜か水曜で30分いただけますか。\n自分: 水曜の午後なら空いてる",
      ja: "水曜の午後でしたら可能です。15時スタートでいかがでしょうか。",
      en: "Wednesday afternoon works. Would 3:00 PM work as a start time?",
    },
    translate: {
      input: "Please find the attached deck for tomorrow's review.",
      ja: "明日のレビュー用に、資料を添付しています。",
      en: "Please find the attached deck for tomorrow's review.",
    },
    speak: {
      input: "来週のリリースは遅れる見込みです。先に関係者へ共有します。",
      scripts: {
        plain: "来週のリリースは遅れる見込みです。先に関係者へ共有します。",
        radio: "今日の短いニュースです。来週のリリースは遅れそうです。関係者には、先にお伝えしておきます。",
        summary: "来週のリリースは遅れます。関係者には先に共有します。",
      },
    },
  };

  const panel = document.querySelector(".panel-hero");
  const inputEl = document.querySelector(".ghost-input");
  const grokEl = document.querySelector("[data-role='grok']");
  const speakScriptEl = document.querySelector("[data-role='speak-script']");
  const runEl = document.querySelector("[data-role='run']");
  const speakStyles = document.querySelector(".speak-styles");
  const textCard = document.querySelector('.result-card[data-kind="text"]');
  const speakCard = document.querySelector('.result-card[data-kind="speak"]');
  const dropHint = document.querySelector(".drop-hint");
  const modes = document.querySelectorAll(".panel .mode");
  const historyItems = document.querySelectorAll(".history-item");
  const styleChips = document.querySelectorAll(".style-chip");
  const langButtons = document.querySelectorAll(".lang-btn");

  let currentMode = "polish";
  let currentLang = "ja";
  let currentStyle = "plain";

  const applyMode = (mode) => {
    const sample = samples[mode];
    if (!sample || !inputEl) return;

    currentMode = mode;
    const isSpeak = mode === "speak";

    modes.forEach((button) => {
      const on = button.dataset.mode === mode;
      button.classList.toggle("is-on", on);
      button.setAttribute("aria-selected", on ? "true" : "false");
    });
    historyItems.forEach((item) => {
      item.classList.toggle("is-on", item.dataset.mode === mode);
    });

    inputEl.textContent = sample.input;
    if (speakStyles) speakStyles.hidden = !isSpeak;
    if (textCard) {
      textCard.hidden = isSpeak;
      textCard.setAttribute("aria-hidden", isSpeak ? "true" : "false");
    }
    if (speakCard) {
      speakCard.hidden = !isSpeak;
      speakCard.setAttribute("aria-hidden", isSpeak ? "false" : "true");
    }
    if (runEl) runEl.textContent = isSpeak ? "読み上げ ⌘⏎" : "実行 ⌘⏎";
    if (dropHint) {
      dropHint.textContent = isSpeak
        ? "読み上げたい文章を入力、または HTML / Markdown をドロップ"
        : "テキストの貼り付け、または HTML / Markdown のドロップ";
    }

    if (isSpeak) {
      applySpeakStyle(currentStyle);
    } else if (grokEl) {
      grokEl.textContent = currentLang === "en" ? sample.en : sample.ja;
    }

    panel?.classList.toggle("is-speak", isSpeak);
  };

  const applySpeakStyle = (style) => {
    currentStyle = style;
    styleChips.forEach((chip) => {
      chip.classList.toggle("is-on", chip.dataset.style === style);
    });
    const script = samples.speak.scripts[style];
    if (speakScriptEl && script) {
      speakScriptEl.textContent = script;
    }
  };

  modes.forEach((button) => {
    button.addEventListener("click", () => applyMode(button.dataset.mode));
  });

  historyItems.forEach((item) => {
    item.addEventListener("click", () => applyMode(item.dataset.mode));
  });

  styleChips.forEach((chip) => {
    chip.addEventListener("click", () => applySpeakStyle(chip.dataset.style));
  });

  langButtons.forEach((button) => {
    button.addEventListener("click", () => {
      currentLang = button.dataset.lang === "en" ? "en" : "ja";
      langButtons.forEach((item) => {
        item.classList.toggle("is-on", item.dataset.lang === currentLang);
      });
      const sample = samples[currentMode];
      if (sample && grokEl && currentMode !== "speak") {
        grokEl.textContent = currentLang === "en" ? sample.en : sample.ja;
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
      { threshold: 0.08, rootMargin: "0px 0px -6% 0px" }
    );
    const viewport = window.innerHeight || 0;
    document.querySelectorAll(".will-reveal").forEach((el) => {
      if (el.getBoundingClientRect().top < viewport * 0.92) {
        el.classList.add("reveal");
      } else {
        observer.observe(el);
      }
    });
    document.documentElement.classList.add("js");
  }
})();
