import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("build_installer", Path(__file__).parents[1] / "build_installer.py")
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)


class InstallerLayoutTests(unittest.TestCase):
    def test_classic_layout_stays_unchanged(self):
        layout = installer.installer_layout("classic")
        self.assertEqual(layout["bounds"], "{{120, 120}, {660, 400}}")
        self.assertEqual(layout["app"], (180, 210))
        self.assertEqual(layout["applications"], (480, 210))

    def test_remotion_layout_matches_empty_background_slots(self):
        layout = installer.installer_layout("remotion")
        self.assertEqual(layout["bounds"], "{{120, 120}, {960, 600}}")
        self.assertEqual(layout["app"], (290, 340))
        self.assertEqual(layout["applications"], (670, 340))
        self.assertEqual(layout["icon_size"], 96)

    def test_unknown_style_rejected(self):
        with self.assertRaises(ValueError):
            installer.installer_layout("unknown")

    def test_demo_filename_and_layout_survive_metadata_serialization(self):
        try:
            from ds_store import DSStore
            from mac_alias import Alias
        except ImportError:
            self.skipTest("install scripts/installer-requirements.txt for serialization check")
        with tempfile.TemporaryDirectory() as temporary:
            mount = Path(temporary)
            alias = unittest.mock.Mock()
            alias.target.posix_path = b"/.background/install.png"
            alias.to_bytes.return_value = b"fixture-volume-relative-alias"
            with patch.object(Alias, "for_file", return_value=alias):
                installer.write_layout(mount, "msgblast Demo.app", "remotion")
            with DSStore.open(str(mount / ".DS_Store"), "r") as store:
                self.assertEqual(store["msgblast Demo.app"]["Iloc"], (290, 340))
                self.assertEqual(store["Applications"]["Iloc"], (670, 340))
                self.assertEqual(store["."]["bwsp"]["WindowBounds"], "{{120, 120}, {960, 600}}")
                self.assertEqual(store["."]["icvp"]["iconSize"], 96)


if __name__ == "__main__":
    unittest.main()
