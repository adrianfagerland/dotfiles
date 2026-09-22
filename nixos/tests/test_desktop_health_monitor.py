import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    'monitor', Path(__file__).parents[1] / 'scripts/desktop-health-monitor.py')
monitor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(monitor)


class MonitoringLifetimeTests(unittest.TestCase):
    def test_missing_or_expired_window_never_samples(self):
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory)
            with patch.object(monitor, 'STATE', state), patch.object(monitor, 'sample') as sample:
                monitor.main()
                (state / 'until').write_text('0')
                monitor.main()
                sample.assert_not_called()
                self.assertFalse((state / 'samples.jsonl').exists())

    def test_active_window_rotates_and_stops_at_expiry(self):
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory)
            (state / 'until').write_text('10')
            (state / 'samples.jsonl').write_text('old sample\n')
            (state / 'samples.jsonl.1').write_text('older sample\n')
            with patch.object(monitor, 'STATE', state), \
                    patch.object(monitor, 'MAX_LOG_BYTES', 1), \
                    patch.object(monitor, 'sample', return_value={'time': 9}) as sample, \
                    patch.object(monitor.time, 'time', side_effect=[9, 10]), \
                    patch.object(monitor.time, 'sleep'):
                monitor.main()
            sample.assert_called_once_with(0)
            self.assertEqual((state / 'samples.jsonl.1').read_text(), 'old sample\n')
            self.assertEqual(json.loads((state / 'samples.jsonl').read_text()), {'time': 9})


if __name__ == '__main__':
    unittest.main()
