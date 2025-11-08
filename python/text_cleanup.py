#!/usr/bin/env python3
"""
Text cleanup module using local LLM for post-processing transcriptions.
"""

import logging
from typing import Optional
from pathlib import Path
import json

try:
    from mlx_lm import load, generate
except ImportError:
    logging.warning("mlx-lm not installed. Text cleanup will be disabled.")
    load = None
    generate = None


# Default system prompts for different use cases
DEFAULT_PROMPTS = {
    "general": """You are a text cleanup assistant. Fix any transcription errors, formatting issues, and improve readability. Keep the same meaning but make it more natural and correctly formatted. Do not add extra information or change the meaning.

Rules:
- Fix obvious transcription errors
- Correct punctuation and capitalization
- Keep the text concise
- Return ONLY the cleaned text, nothing else""",

    "coding": """You are a coding transcription cleanup assistant. Fix transcription errors and format code-related content properly.

Rules:
- Convert spoken file references to proper format (e.g., "main dot py" → "main.py")
- Format code variable names properly (e.g., "get user by ID" → "getUserById")
- Use @ symbol for file mentions when appropriate (e.g., "in the file main dot py" → "in the file @main.py")
- Fix technical terminology and programming language names
- Keep code snippets and commands properly formatted
- Return ONLY the cleaned text, nothing else""",

    "punctuation": """You are a punctuation assistant. Add proper punctuation and capitalization to transcribed text while keeping it natural.

Rules:
- Add periods, commas, and appropriate punctuation
- Capitalize sentence beginnings and proper nouns
- Keep the exact same words, only fix punctuation
- Return ONLY the cleaned text, nothing else"""
}


class TextCleanup:
    """Handles LLM-based text cleanup for transcriptions."""

    def __init__(
        self,
        model_name: str = "mlx-community/Qwen2.5-0.5B-Instruct-4bit",
        enabled: bool = True,
        custom_prompts: Optional[dict] = None
    ):
        self.model_name = model_name
        self.enabled = enabled and (load is not None and generate is not None)
        self.model = None
        self.tokenizer = None
        self.prompts = {**DEFAULT_PROMPTS}

        if custom_prompts:
            self.prompts.update(custom_prompts)

        if self.enabled:
            self._load_model()
        else:
            logging.warning("Text cleanup is disabled (mlx-lm not available or disabled)")

    def _load_model(self):
        """Load the LLM model for text cleanup."""
        try:
            logging.info(f"Loading text cleanup model: {self.model_name}")
            self.model, self.tokenizer = load(self.model_name)
            logging.info("Text cleanup model loaded successfully")
        except Exception as e:
            logging.error(f"Failed to load text cleanup model: {e}")
            self.enabled = False
            raise

    def cleanup(self, text: str, prompt_type: str = "general", max_tokens: int = 512) -> str:
        """
        Clean up transcribed text using the LLM.

        Args:
            text: The transcribed text to clean up
            prompt_type: Which system prompt to use ("general", "coding", "punctuation", or custom)
            max_tokens: Maximum tokens to generate

        Returns:
            Cleaned up text, or original text if cleanup is disabled or fails
        """
        if not self.enabled or not text or not text.strip():
            return text

        try:
            # Get the system prompt
            system_prompt = self.prompts.get(prompt_type, self.prompts["general"])

            # Format the prompt for the model
            messages = [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": f"Clean up this text:\n\n{text}"}
            ]

            # Apply chat template
            prompt = self.tokenizer.apply_chat_template(
                messages,
                tokenize=False,
                add_generation_prompt=True
            )

            logging.info(f"Cleaning up text with {prompt_type} prompt (length: {len(text)} chars)")

            # Generate cleaned text
            response = generate(
                self.model,
                self.tokenizer,
                prompt=prompt,
                max_tokens=max_tokens,
                temp=0.3,  # Low temperature for more consistent output
                verbose=False
            )

            # Extract the generated text (remove the prompt)
            cleaned_text = response[len(prompt):].strip()

            logging.info(f"Text cleanup complete (output length: {len(cleaned_text)} chars)")

            # Fallback to original if output is empty or suspiciously short
            if not cleaned_text or len(cleaned_text) < len(text) * 0.3:
                logging.warning("Cleanup output too short, using original text")
                return text

            return cleaned_text

        except Exception as e:
            logging.error(f"Text cleanup failed: {e}, using original text")
            return text

    def add_custom_prompt(self, name: str, prompt: str):
        """Add or update a custom system prompt."""
        self.prompts[name] = prompt
        logging.info(f"Added custom prompt: {name}")

    def get_available_prompts(self) -> list:
        """Get list of available prompt types."""
        return list(self.prompts.keys())


def load_custom_prompts(config_path: str = "~/.voice_transcriber_prompts.json") -> dict:
    """Load custom prompts from a JSON config file."""
    try:
        path = Path(config_path).expanduser()
        if path.exists():
            with open(path, 'r') as f:
                return json.load(f)
    except Exception as e:
        logging.warning(f"Could not load custom prompts from {config_path}: {e}")
    return {}
