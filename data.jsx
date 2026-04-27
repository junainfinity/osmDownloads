// Seed data for prototype
const SEED_PRESETS = {
  // typing this URL into the bar will resolve to this preset
  'https://huggingface.co/meta-llama/Llama-3.1-8B-Instruct': {
    kind: 'hf',
    title: 'meta-llama/Llama-3.1-8B-Instruct',
    subtitle: 'Repository · main branch · 14 files',
    files: [
      { name: 'model-00001-of-00004.safetensors', size: 4_976_000_000, sel: true, group: 'weights' },
      { name: 'model-00002-of-00004.safetensors', size: 4_999_000_000, sel: true, group: 'weights' },
      { name: 'model-00003-of-00004.safetensors', size: 4_915_000_000, sel: true, group: 'weights' },
      { name: 'model-00004-of-00004.safetensors', size: 1_168_000_000, sel: true, group: 'weights' },
      { name: 'model.safetensors.index.json', size: 25_000, sel: true, group: 'config' },
      { name: 'config.json', size: 826, sel: true, group: 'config' },
      { name: 'tokenizer.json', size: 9_085_000, sel: true, group: 'tokenizer' },
      { name: 'tokenizer_config.json', size: 51_000, sel: true, group: 'tokenizer' },
      { name: 'special_tokens_map.json', size: 296, sel: true, group: 'tokenizer' },
      { name: 'generation_config.json', size: 184, sel: true, group: 'config' },
      { name: 'README.md', size: 41_000, sel: true, group: 'docs' },
      { name: 'LICENSE.txt', size: 7_700, sel: true, group: 'docs' },
      { name: 'USE_POLICY.md', size: 4_200, sel: false, group: 'docs' },
      { name: 'original/consolidated.00.pth', size: 16_060_000_000, sel: false, group: 'original' },
    ],
  },
  'https://github.com/openai/whisper': {
    kind: 'gh',
    title: 'openai/whisper',
    subtitle: 'Release · v20240930 · 6 assets',
    files: [
      { name: 'whisper-20240930-py3-none-any.whl', size: 805_000, sel: true },
      { name: 'whisper-20240930.tar.gz', size: 1_204_000, sel: true },
      { name: 'Source code (zip)', size: 12_400_000, sel: false },
      { name: 'Source code (tar.gz)', size: 9_800_000, sel: false },
      { name: 'CHANGELOG.md', size: 38_000, sel: true },
      { name: 'README.md', size: 22_000, sel: true },
    ],
  },
  'https://example.com/big-archive.zip': {
    kind: 'unsupported',
    title: 'big-archive.zip',
    subtitle: 'example.com',
    files: [],
  },
};

// Active and historical jobs at app start
const NOW = Date.now();
const SEED_JOBS = [
  {
    id: 'j1',
    kind: 'hf',
    title: 'stabilityai/stable-diffusion-xl-base-1.0',
    subtitle: 'huggingface.co · 8 of 12 files',
    dest: '~/Models/sdxl-base-1.0',
    started: NOW - 4 * 60 * 1000,
    status: 'downloading',
    speed: 86_500_000, // 86 MB/s
    files: [
      { name: 'sd_xl_base_1.0.safetensors', size: 6_938_000_000, downloaded: 4_120_000_000, status: 'active' },
      { name: 'sd_xl_base_1.0_0.9vae.safetensors', size: 6_938_000_000, downloaded: 6_938_000_000, status: 'done' },
      { name: 'unet/diffusion_pytorch_model.safetensors', size: 5_135_000_000, downloaded: 5_135_000_000, status: 'done' },
      { name: 'vae/diffusion_pytorch_model.safetensors', size: 334_000_000, downloaded: 334_000_000, status: 'done' },
      { name: 'text_encoder/model.safetensors', size: 246_000_000, downloaded: 246_000_000, status: 'done' },
      { name: 'text_encoder_2/model.safetensors', size: 1_389_000_000, downloaded: 980_000_000, status: 'active' },
      { name: 'tokenizer/vocab.json', size: 1_059_000, downloaded: 1_059_000, status: 'done' },
      { name: 'tokenizer/merges.txt', size: 525_000, downloaded: 525_000, status: 'done' },
      { name: 'tokenizer_2/vocab.json', size: 862_000, downloaded: 0, status: 'queued' },
      { name: 'scheduler/scheduler_config.json', size: 479, downloaded: 479, status: 'done' },
      { name: 'model_index.json', size: 609, downloaded: 609, status: 'done' },
      { name: 'README.md', size: 14_000, downloaded: 0, status: 'queued' },
    ],
  },
  {
    id: 'j2',
    kind: 'hf',
    title: 'mistralai/Mistral-7B-Instruct-v0.3',
    subtitle: 'huggingface.co · 9 files',
    dest: '~/Models/mistral-7b-v0.3',
    started: NOW - 12 * 60 * 1000,
    status: 'paused',
    speed: 0,
    files: [
      { name: 'consolidated.safetensors', size: 14_500_000_000, downloaded: 8_700_000_000, status: 'paused' },
      { name: 'tokenizer.model.v3', size: 587_000, downloaded: 587_000, status: 'done' },
      { name: 'config.json', size: 612, downloaded: 612, status: 'done' },
      { name: 'params.json', size: 215, downloaded: 215, status: 'done' },
      { name: 'tokenizer_config.json', size: 49_000, downloaded: 49_000, status: 'done' },
      { name: 'special_tokens_map.json', size: 414, downloaded: 414, status: 'done' },
      { name: 'generation_config.json', size: 116, downloaded: 116, status: 'done' },
      { name: 'README.md', size: 7_800, downloaded: 7_800, status: 'done' },
      { name: 'LICENSE', size: 11_000, downloaded: 11_000, status: 'done' },
    ],
  },
  {
    id: 'j3',
    kind: 'gh',
    title: 'ggerganov/llama.cpp · b3621',
    subtitle: 'github.com · release assets',
    dest: '~/Apps/llama.cpp',
    started: NOW - 35 * 1000,
    status: 'queued',
    speed: 0,
    files: [
      { name: 'llama-b3621-bin-macos-arm64.zip', size: 28_400_000, downloaded: 0, status: 'queued' },
      { name: 'cudart-llama-bin-win-cu12.2.0-x64.zip', size: 168_000_000, downloaded: 0, status: 'queued' },
      { name: 'llama-b3621-bin-ubuntu-x64.zip', size: 24_900_000, downloaded: 0, status: 'queued' },
    ],
  },
];

const SEED_HISTORY = [
  {
    id: 'h1', kind: 'hf', status: 'completed',
    title: 'BAAI/bge-m3', subtitle: '8 files · 2.27 GB',
    dest: '~/Models/bge-m3',
    finished: NOW - 2 * 3600 * 1000, duration: 38, totalSize: 2_270_000_000,
  },
  {
    id: 'h2', kind: 'gh', status: 'completed',
    title: 'oobabooga/text-generation-webui · v2.4', subtitle: '4 assets · 412 MB',
    dest: '~/Downloads/text-gen-webui',
    finished: NOW - 8 * 3600 * 1000, duration: 12, totalSize: 412_000_000,
  },
  {
    id: 'h3', kind: 'hf', status: 'failed',
    title: 'TheBloke/Llama-2-70B-GGUF', subtitle: 'connection lost · 4.1 of 38 GB',
    dest: '~/Models/llama2-70b-gguf',
    finished: NOW - 26 * 3600 * 1000, duration: 612, totalSize: 38_000_000_000,
    error: 'Network error after 612s — peer reset (ECONNRESET)',
  },
  {
    id: 'h4', kind: 'hf', status: 'completed',
    title: 'sentence-transformers/all-MiniLM-L6-v2', subtitle: '11 files · 91 MB',
    dest: '~/Models/all-MiniLM-L6-v2',
    finished: NOW - 2 * 86400 * 1000, duration: 6, totalSize: 91_000_000,
  },
  {
    id: 'h5', kind: 'gh', status: 'cancelled',
    title: 'ollama/ollama · v0.4.2 (linux-amd64)', subtitle: 'cancelled at 28%',
    dest: '~/Downloads/ollama',
    finished: NOW - 3 * 86400 * 1000, duration: 9, totalSize: 1_840_000_000,
  },
  {
    id: 'h6', kind: 'hf', status: 'completed',
    title: 'black-forest-labs/FLUX.1-schnell', subtitle: '14 files · 23.8 GB',
    dest: '~/Models/flux-schnell',
    finished: NOW - 5 * 86400 * 1000, duration: 286, totalSize: 23_800_000_000,
  },
  {
    id: 'h7', kind: 'gh', status: 'completed',
    title: 'huggingface/transformers · v4.45.0', subtitle: '2 assets · 9.4 MB',
    dest: '~/Downloads/transformers',
    finished: NOW - 7 * 86400 * 1000, duration: 2, totalSize: 9_400_000,
  },
  {
    id: 'h8', kind: 'hf', status: 'failed',
    title: 'CompVis/stable-diffusion-v-1-4-original', subtitle: 'auth required',
    dest: '~/Models/sd-v1-4',
    finished: NOW - 9 * 86400 * 1000, duration: 1, totalSize: 4_270_000_000,
    error: 'HTTP 401 — gated repo. Add a Hugging Face token in Settings.',
  },
];

Object.assign(window, { SEED_PRESETS, SEED_JOBS, SEED_HISTORY });
