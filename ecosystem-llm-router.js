/**
 * Ecosystem LLM Fallback Router (JS)
 * Multi-provider, zero-dependency LLM failover client for Montanha WhatsApp Automation.
 * Integrates Free LLM API providers: Google Gemini, Groq, Cerebras, SambaNova, and OpenRouter.
 */

const ECOSYSTEM_PROVIDERS = [
  {
    name: "gemini",
    baseUrl: "https://generativelanguage.googleapis.com/v1beta/models/",
    envKey: "VITE_GEMINI_API_KEY",
    defaultModel: "gemini-2.5-flash",
    format: "gemini",
  },
  {
    name: "groq",
    baseUrl: "https://api.groq.com/openai/v1/chat/completions",
    envKey: "VITE_GROQ_API_KEY",
    defaultModel: "llama-3.3-70b-versatile",
    format: "openai",
  },
  {
    name: "cerebras",
    baseUrl: "https://api.cerebras.ai/v1/chat/completions",
    envKey: "VITE_CEREBRAS_API_KEY",
    defaultModel: "llama3.1-70b",
    format: "openai",
  },
  {
    name: "sambanova",
    baseUrl: "https://api.sambanova.ai/v1/chat/completions",
    envKey: "VITE_SAMBANOVA_API_KEY",
    defaultModel: "Meta-Llama-3.3-70B-Instruct",
    format: "openai",
  },
  {
    name: "openrouter",
    baseUrl: "https://openrouter.ai/api/v1/chat/completions",
    envKey: "VITE_OPENROUTER_API_KEY",
    defaultModel: "meta-llama/llama-3.3-70b-instruct:free",
    format: "openai",
  },
];

function getApiKey(envKey) {
  if (typeof process !== "undefined" && process.env && process.env[envKey]) {
    return process.env[envKey] || null;
  }
  if (typeof window !== "undefined" && window[envKey]) {
    return window[envKey];
  }
  return null;
}

async function generateEcosystemCompletion(options) {
  const startTime = Date.now();
  let messages = options.messages ? [...options.messages] : [];

  if (options.systemInstruction && !messages.some((m) => m.role === "system")) {
    messages.unshift({ role: "system", content: options.systemInstruction });
  }
  if (options.prompt && messages.length === 0) {
    messages.push({ role: "user", content: options.prompt });
  }

  let providersToTry = [...ECOSYSTEM_PROVIDERS];
  if (options.preferredProvider) {
    const prefIdx = providersToTry.findIndex((p) => p.name === options.preferredProvider);
    if (prefIdx > -1) {
      const [preferred] = providersToTry.splice(prefIdx, 1);
      providersToTry.unshift(preferred);
    }
  }

  let lastError = null;

  for (const provider of providersToTry) {
    const apiKey = getApiKey(provider.envKey) || getApiKey("VITE_GEMINI_API_KEY");
    if (!apiKey && provider.name !== "gemini") {
      continue;
    }

    try {
      if (provider.format === "gemini") {
        const text = await callGeminiAPI(apiKey || "", messages, options, provider.defaultModel);
        if (text) {
          return {
            text,
            providerUsed: provider.name,
            modelUsed: provider.defaultModel,
            durationMs: Date.now() - startTime,
          };
        }
      } else {
        const text = await callOpenAICompatibleAPI(provider, apiKey || "", messages, options);
        if (text) {
          return {
            text,
            providerUsed: provider.name,
            modelUsed: provider.defaultModel,
            durationMs: Date.now() - startTime,
          };
        }
      }
    } catch (err) {
      console.warn(`[ECO-LLM-ROUTER] ${provider.name} falhou:`, err?.message || err);
      lastError = err;
    }
  }

  throw lastError || new Error("Todos os provedores de LLM do ecossistema falharam ou estão sem chave configurada.");
}

async function callOpenAICompatibleAPI(provider, apiKey, messages, options) {
  const response = await fetch(provider.baseUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: provider.defaultModel,
      messages: messages,
      temperature: options.temperature ?? 0.7,
      max_tokens: options.maxTokens ?? 1024,
    }),
  });

  if (!response.ok) {
    const errData = await response.json().catch(() => ({}));
    throw new Error(errData?.error?.message || `HTTP ${response.status} de ${provider.name}`);
  }

  const data = await response.json();
  const text = data?.choices?.[0]?.message?.content;
  if (!text) {
    throw new Error(`Resposta vazia do provedor ${provider.name}`);
  }
  return text;
}

async function callGeminiAPI(apiKey, messages, options, modelName) {
  const userMsg = messages.filter((m) => m.role === "user").map((m) => m.content).join("\n\n");
  const sysMsg = messages.find((m) => m.role === "system")?.content;

  const body = {
    contents: [{ role: "user", parts: [{ text: userMsg || options.prompt || "" }] }],
    generationConfig: {
      temperature: options.temperature ?? 0.7,
      maxOutputTokens: options.maxTokens ?? 1024,
    },
  };

  if (sysMsg) {
    body.systemInstruction = { parts: [{ text: sysMsg }] };
  }

  const url = `https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent?key=${apiKey}`;
  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    const errData = await response.json().catch(() => ({}));
    throw new Error(errData?.error?.message || `HTTP ${response.status} de Gemini`);
  }

  const data = await response.json();
  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) {
    throw new Error("Resposta vazia da API Gemini");
  }
  return text;
}

if (typeof window !== "undefined") {
  window.EcosystemLLMRouter = {
    generateEcosystemCompletion,
    ECOSYSTEM_PROVIDERS,
  };
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    generateEcosystemCompletion,
    ECOSYSTEM_PROVIDERS,
  };
}
