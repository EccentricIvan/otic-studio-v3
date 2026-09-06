#!/usr/bin/env python3
"""Quantize the two local SLMs to 4-bit AWQ (group size 128).

Deployment layout (written under the repo, gitignored like other model bytes):

    assets/models/translation_4bit/   ← qvac/TranslatePsy-AfriSLM-800M
    assets/models/brain_4bit/         ← Qwen/Qwen3-0.6B-Instruct

The Flutter app does **not** load these folders at runtime. Chat stays on
LiteRT-LM (``.litertlm``) and translation stays on in-process llama.cpp
(``.gguf``). This script is the workstation step that produces a 4-bit
checkpoint you can convert onward (e.g. AWQ → GGUF via llama.cpp) or keep
for an ONNX export. Peak RAM while quantizing is a desktop concern; the
on-device budget is documented in ``docs/DUAL_MODEL_MEMORY.md``.

Usage (from repo root, with the unquantized HF trees on disk):

    pip install -r tools/requirements-awq.txt
    python tools/quantize_awq.py --local-only

Override sources with ``--translation-src`` / ``--brain-src`` or the env
vars ``TRANSLATION_MODEL`` and ``BRAIN_MODEL``.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
DEFAULT_OUT_TRANSLATION = REPO / "assets" / "models" / "translation_4bit"
DEFAULT_OUT_BRAIN = REPO / "assets" / "models" / "brain_4bit"

# Hugging Face ids (only used when a local folder is missing and --local-only
# is off). Prefer a checked-out tree next to the repo.
HF_TRANSLATION = "qvac/TranslatePsy-AfriSLM-800M"
HF_BRAIN = "Qwen/Qwen3-0.6B-Instruct"

LOCAL_CANDIDATES_TRANSLATION = (
    REPO / "models" / "TranslatePsy-AfriSLM-800M",
    REPO / "models" / "qvac" / "TranslatePsy-AfriSLM-800M",
    REPO / "assets" / "models" / "TranslatePsy-AfriSLM-800M",
)
LOCAL_CANDIDATES_BRAIN = (
    REPO / "models" / "Qwen3-0.6B-Instruct",
    REPO / "models" / "Qwen" / "Qwen3-0.6B-Instruct",
    REPO / "assets" / "models" / "Qwen3-0.6B-Instruct",
)

AWQ_CONFIG = {
    "zero_point": True,
    "q_group_size": 128,
    "w_bit": 4,
    "version": "GEMM",
}


def _first_existing(paths: tuple[Path, ...]) -> Path | None:
    for p in paths:
        if p.is_dir() and any(p.iterdir()):
            return p
    return None


def resolve_src(cli: str | None, env_key: str, locals_: tuple[Path, ...], hf_id: str, local_only: bool) -> str:
    if cli:
        return cli
    env = os.environ.get(env_key, "").strip()
    if env:
        return env
    found = _first_existing(locals_)
    if found:
        return str(found)
    if local_only:
        raise SystemExit(
            f"No local folder for {hf_id}. Pass --translation-src / --brain-src "
            f"or place the HF tree under ./models/."
        )
    return hf_id


def quantize_one(src: str, dest: Path, *, model_kind: str) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    print(f"[{model_kind}] loading {src}", flush=True)

    try:
        from awq import AutoAWQForCausalLM
        from transformers import AutoTokenizer
    except ImportError as e:
        raise SystemExit(
            "autoawq / transformers not installed. "
            "Run: pip install -r tools/requirements-awq.txt"
        ) from e

    # Decoder-only / causal LM share the same AutoAWQ causal loader.
    model = AutoAWQForCausalLM.from_pretrained(
        src,
        low_cpu_mem_usage=True,
        use_cache=False,
        trust_remote_code=True,
    )
    tokenizer = AutoTokenizer.from_pretrained(src, trust_remote_code=True)

    print(f"[{model_kind}] quantizing w_bit=4 q_group_size=128", flush=True)
    model.quantize(tokenizer, quant_config=AWQ_CONFIG)

    print(f"[{model_kind}] saving {dest}", flush=True)
    model.save_quantized(str(dest))
    tokenizer.save_pretrained(str(dest))

    meta = {
        "source": src,
        "kind": model_kind,
        "quant": AWQ_CONFIG,
        "saved_at": datetime.now(timezone.utc).isoformat(),
        "runtime_note": (
            "AWQ safetensors. Convert to GGUF for llama.cpp or keep LiteRT-LM "
            "for the chat brain. Do not commit this folder."
        ),
    }
    (dest / "awq_manifest.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
    print(f"[{model_kind}] done", flush=True)


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--translation-src")
    p.add_argument("--brain-src")
    p.add_argument("--translation-out", type=Path, default=DEFAULT_OUT_TRANSLATION)
    p.add_argument("--brain-out", type=Path, default=DEFAULT_OUT_BRAIN)
    p.add_argument(
        "--local-only",
        action="store_true",
        help="Refuse Hugging Face downloads; require a local model directory.",
    )
    p.add_argument("--skip-translation", action="store_true")
    p.add_argument("--skip-brain", action="store_true")
    args = p.parse_args(argv)

    if not args.skip_translation:
        src = resolve_src(
            args.translation_src,
            "TRANSLATION_MODEL",
            LOCAL_CANDIDATES_TRANSLATION,
            HF_TRANSLATION,
            args.local_only,
        )
        quantize_one(src, args.translation_out, model_kind="translation")

    if not args.skip_brain:
        src = resolve_src(
            args.brain_src,
            "BRAIN_MODEL",
            LOCAL_CANDIDATES_BRAIN,
            HF_BRAIN,
            args.local_only,
        )
        quantize_one(src, args.brain_out, model_kind="brain")

    return 0


if __name__ == "__main__":
    sys.exit(main())
