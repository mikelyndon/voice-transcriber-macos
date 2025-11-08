#!/usr/bin/env python3
"""
Transcription server for Voice Transcriber app.
Listens for audio file paths via stdin and returns transcribed text as JSON.
"""

import json
import sys
import logging
from pathlib import Path
from typing import Optional

try:
    from parakeet_mlx import from_pretrained
except ImportError:
    print(json.dumps({"error": "parakeet_mlx not installed. Run: uv add parakeet-mlx"}))
    sys.exit(1)

try:
    from text_cleanup import TextCleanup, load_custom_prompts
except ImportError:
    logging.warning("text_cleanup module not found, cleanup will be disabled")
    TextCleanup = None
    load_custom_prompts = None


class TranscriptionServer:
    def __init__(
        self,
        model_name: str = "mlx-community/parakeet-tdt-0.6b-v2",
        cleanup_enabled: bool = True,
        cleanup_model: str = "mlx-community/Qwen2.5-0.5B-Instruct-4bit",
        cleanup_prompt: str = "general"
    ):
        self.model = None
        self.model_name = model_name
        self.cleanup_enabled = cleanup_enabled
        self.cleanup_prompt = cleanup_prompt
        self.text_cleanup = None

        self._load_model()

        # Load text cleanup if enabled
        if cleanup_enabled and TextCleanup is not None:
            try:
                custom_prompts = load_custom_prompts() if load_custom_prompts else {}
                self.text_cleanup = TextCleanup(
                    model_name=cleanup_model,
                    enabled=True,
                    custom_prompts=custom_prompts
                )
            except Exception as e:
                logging.warning(f"Failed to initialize text cleanup: {e}")
                self.text_cleanup = None
    
    def _load_model(self):
        """Load the Parakeet model."""
        try:
            logging.info(f"Loading model: {self.model_name}")
            self.model = from_pretrained(self.model_name)
            logging.info("Model loaded successfully")
        except Exception as e:
            logging.error(f"Failed to load model: {e}")
            raise
    
    def transcribe(self, audio_path: str, cleanup_prompt: Optional[str] = None) -> dict:
        """Transcribe audio file and return result as dict."""
        try:
            if not Path(audio_path).exists():
                return {"error": f"Audio file not found: {audio_path}"}

            logging.info(f"Transcribing: {audio_path}")
            result = self.model.transcribe(audio_path)

            # Get the original transcribed text
            original_text = result.text
            cleaned_text = original_text

            # Apply text cleanup if enabled
            if self.text_cleanup and self.cleanup_enabled:
                prompt_type = cleanup_prompt or self.cleanup_prompt
                logging.info(f"Applying text cleanup with prompt: {prompt_type}")
                cleaned_text = self.text_cleanup.cleanup(original_text, prompt_type=prompt_type)

            return {
                "success": True,
                "text": cleaned_text,
                "original_text": original_text if cleaned_text != original_text else None,
                "sentences": [
                    {
                        "text": sentence.text,
                        "start": sentence.start,
                        "end": sentence.end,
                        "duration": sentence.duration
                    }
                    for sentence in result.sentences
                ]
            }
        except Exception as e:
            logging.error(f"Transcription failed: {e}")
            return {"error": f"Transcription failed: {str(e)}"}
    
    def run(self):
        """Main server loop - read commands from stdin."""
        logging.info("Transcription server started and listening for commands")
        
        for line in sys.stdin:
            try:
                logging.info(f"Received command: {line.strip()}")
                command = json.loads(line.strip())
                action = command.get("action")
                logging.info(f"Processing action: {action}")
                
                if action == "transcribe":
                    audio_path = command.get("audio_path")
                    cleanup_prompt = command.get("cleanup_prompt")  # Optional prompt override
                    if not audio_path:
                        logging.error("Transcribe command missing audio_path parameter")
                        response = {"error": "Missing audio_path parameter"}
                    else:
                        logging.info(f"Starting transcription for: {audio_path}")
                        response = self.transcribe(audio_path, cleanup_prompt=cleanup_prompt)
                        logging.info(f"Transcription completed with response: {response}")
                
                elif action == "ping":
                    logging.info("Ping command received")
                    response = {"success": True, "message": "pong"}
                
                elif action == "quit":
                    logging.info("Quit command received")
                    response = {"success": True, "message": "Shutting down"}
                    print(json.dumps(response))
                    break
                
                else:
                    logging.warning(f"Unknown action received: {action}")
                    response = {"error": f"Unknown action: {action}"}
                
                logging.info(f"Sending response: {response}")
                print(json.dumps(response))
                sys.stdout.flush()
                
            except json.JSONDecodeError as e:
                logging.error(f"JSON decode error: {str(e)}")
                error_response = {"error": f"Invalid JSON: {str(e)}"}
                print(json.dumps(error_response))
                sys.stdout.flush()
            except Exception as e:
                logging.error(f"Unexpected server error: {str(e)}")
                error_response = {"error": f"Server error: {str(e)}"}
                print(json.dumps(error_response))
                sys.stdout.flush()


def main():
    # Set up logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler('/tmp/voice_transcriber.log'),
            logging.StreamHandler(sys.stderr)
        ]
    )
    
    try:
        server = TranscriptionServer()
        server.run()
    except Exception as e:
        logging.error(f"Server startup failed: {e}")
        print(json.dumps({"error": f"Server startup failed: {str(e)}"}))
        sys.exit(1)


if __name__ == "__main__":
    main()