#!/usr/bin/env python3
"""
Configuration parser for Fast ICA framework.
This module loads and manages configuration from YAML files.
"""

import os
import sys
import yaml
import logging
import argparse
from datetime import datetime
from pathlib import Path

# Base directory of the project
BASE_DIR = Path(__file__).resolve().parent.parent.parent

# Default configuration file
DEFAULT_CONFIG_FILE = BASE_DIR / "config" / "default.yml"

# Environment variable for config override
CONFIG_ENV_VAR = "FAST_ICA_CONFIG"

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger("config")

class ConfigManager:
    """
    Manages configuration for Fast ICA processing framework.
    Loads configuration from YAML files and environment variables.
    """
    
    def __init__(self, config_file=None, env=None):
        """
        Initialize the configuration manager.
        
        Args:
            config_file (str, optional): Path to custom config file. Defaults to None.
            env (str, optional): Environment to use (local, server, container). Defaults to None.
        """
        self.config = {}
        self.env = env or self._detect_environment()
        
        # Load default configuration
        self._load_default_config()
        
        # Load custom configuration if provided
        if config_file:
            self._load_custom_config(config_file)
        elif os.environ.get(CONFIG_ENV_VAR):
            self._load_custom_config(os.environ.get(CONFIG_ENV_VAR))
            
        # Setup logging based on config
        self._setup_logging()
        
        logger.info(f"Configuration loaded for environment: {self.env}")
    
    def _detect_environment(self):
        """
        Detect the current environment based on system properties.
        
        Returns:
            str: Detected environment (local, server, container)
        """
        # Simple heuristic to detect environment
        if os.path.exists("/.dockerenv") or os.path.exists("/.singularity.d"):
            return "container"
        elif os.path.exists("/etc/slurm") or "SLURM_JOB_ID" in os.environ:
            return "server"
        else:
            return "local"
    
    def _load_default_config(self):
        """Load the default configuration file."""
        try:
            with open(DEFAULT_CONFIG_FILE, "r") as file:
                self.config = yaml.safe_load(file)
            logger.debug("Loaded default configuration")
        except Exception as e:
            logger.error(f"Error loading default config: {e}")
            sys.exit(1)
    
    def _load_custom_config(self, config_path):
        """
        Load a custom configuration file and merge with default config.
        
        Args:
            config_path (str): Path to custom config file
        """
        try:
            with open(config_path, "r") as file:
                custom_config = yaml.safe_load(file)
                
            # Recursive merge of dictionaries
            self._deep_merge(self.config, custom_config)
            logger.debug(f"Loaded custom configuration from {config_path}")
        except Exception as e:
            logger.error(f"Error loading custom config from {config_path}: {e}")
            
    def _deep_merge(self, dest, source):
        """
        Deep merge two dictionaries recursively.
        
        Args:
            dest (dict): Destination dictionary to merge into
            source (dict): Source dictionary to merge from
        """
        for key, value in source.items():
            if key in dest and isinstance(dest[key], dict) and isinstance(value, dict):
                self._deep_merge(dest[key], value)
            else:
                dest[key] = value
    
    def _setup_logging(self):
        """Setup logging based on configuration."""
        if "logging" in self.config:
            log_config = self.config["logging"]
            
            # Create log directory if it doesn't exist
            if log_config.get("log_dir"):
                log_dir = BASE_DIR / log_config["log_dir"]
                log_dir.mkdir(exist_ok=True)
                
                # Setup file handler
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                log_file = log_dir / log_config["file_format"].format(timestamp=timestamp)
                
                file_handler = logging.FileHandler(log_file)
                file_handler.setFormatter(logging.Formatter(
                    "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
                ))
                
                # Set level
                level = getattr(logging, log_config.get("level", "INFO"))
                file_handler.setLevel(level)
                
                # Add to root logger
                logging.getLogger().addHandler(file_handler)
                logging.getLogger().setLevel(level)
    
    def get_matlab_path(self):
        """
        Get the appropriate MATLAB path for the current environment.
        
        Returns:
            str: Path to MATLAB executable
        """
        return self.config["global"]["matlab"].get(self.env, self.config["global"]["matlab"]["local"])
    
    def get_eeglab_path(self):
        """
        Get the EEGLAB path.
        
        Returns:
            str: Path to EEGLAB
        """
        return self.config["global"]["eeglab"]["path"]
    
    def get_matlab_startup_options(self):
        """
        Get MATLAB startup options.
        
        Returns:
            str: MATLAB startup options
        """
        return self.config["global"]["eeglab"]["startup_options"]
    
    def get_implementation_config(self, implementation):
        """
        Get configuration for a specific implementation.
        
        Args:
            implementation (str): Implementation name (parallel, serial, strengthen)
            
        Returns:
            dict: Implementation-specific configuration
        """
        if implementation in self.config["implementations"]:
            return self.config["implementations"][implementation]
        else:
            logger.warning(f"No configuration found for implementation: {implementation}")
            return {}
    
    def get_amica_params(self):
        """
        Get AMICA parameters.
        
        Returns:
            dict: AMICA parameters
        """
        return self.config["global"]["amica"]
    
    def get_project_structure(self):
        """
        Get project structure configuration.
        
        Returns:
            dict: Project structure configuration
        """
        return self.config["project"]["structure"]
    
    def export_matlab_config(self, implementation):
        """
        Export configuration as MATLAB-readable JSON for use in MATLAB scripts.
        
        Args:
            implementation (str): Implementation name
            
        Returns:
            str: Path to generated MATLAB config file
        """
        import json
        import tempfile
        
        # Create a dictionary with all relevant configuration
        matlab_config = {
            "amica": self.get_amica_params(),
            "implementation": self.get_implementation_config(implementation),
            "eeglab_path": self.get_eeglab_path(),
        }
        
        # If strengthen implementation, add project structure
        if implementation == "strengthen":
            matlab_config["project"] = self.get_project_structure()
        
        # Write to temporary file
        temp_file = tempfile.NamedTemporaryFile(delete=False, suffix='.json')
        with open(temp_file.name, 'w') as f:
            json.dump(matlab_config, f, indent=2)
        
        return temp_file.name

def get_config(implementation=None, config_file=None, env=None):
    """
    Get configuration for a specific implementation.
    Helper function to create a ConfigManager instance.
    
    Args:
        implementation (str, optional): Implementation name. Defaults to None.
        config_file (str, optional): Custom config file path. Defaults to None.
        env (str, optional): Environment name. Defaults to None.
        
    Returns:
        tuple: (ConfigManager instance, implementation config dict)
    """
    config_manager = ConfigManager(config_file=config_file, env=env)
    
    if implementation:
        implementation_config = config_manager.get_implementation_config(implementation)
        return config_manager, implementation_config
    
    return config_manager, None

def main():
    """Command-line interface for the config parser."""
    parser = argparse.ArgumentParser(description="Fast ICA Configuration Parser")
    parser.add_argument("--implementation", "-i", choices=["parallel", "serial", "strengthen"],
                        help="Implementation to get configuration for")
    parser.add_argument("--config", "-c", help="Path to custom config file")
    parser.add_argument("--env", "-e", choices=["local", "server", "container"],
                        help="Environment to use")
    parser.add_argument("--export-matlab", "-m", action="store_true",
                        help="Export configuration as MATLAB-readable JSON")
    
    args = parser.parse_args()
    
    config_manager, impl_config = get_config(
        implementation=args.implementation,
        config_file=args.config,
        env=args.env
    )
    
    if args.export_matlab and args.implementation:
        matlab_config_path = config_manager.export_matlab_config(args.implementation)
        print(f"MATLAB configuration exported to: {matlab_config_path}")
    elif impl_config:
        print(yaml.dump(impl_config, default_flow_style=False))
    else:
        print(yaml.dump(config_manager.config, default_flow_style=False))

if __name__ == "__main__":
    main()