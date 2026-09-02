/* ============================================================================
   SHARED SENSOR DSP — FFT, pitch (autocorrelation), RMS / dBFS, A-weighting
   ============================================================================
   One spectral-analysis path used by:
     - Pitch / hum identifier  (spectrum helper; fundamental is autocorrelation)
     - FFT / audio spectrum analyzer
     - Lux meter flicker check (brightness time series, sample rate = camera fps)

   Window: Hann
   Size:   power of two (default 2048). Odd lengths are zero-padded up.
   Bin Hz: sampleRate / fftSize

   Phone mics and cameras are not calibrated instruments. These helpers are
   for relative field checks, not compliance measurements.

   Plain browser script. Pure functions — no getUserMedia, no DOM side effects.
   ============================================================================ */

(function (global) {
  'use strict';

  var DEFAULT_FFT_SIZE = 2048;
  var TWO_PI = Math.PI * 2;

  function nextPow2(n) {
    var p = 1;
    while (p < n) p <<= 1;
    return p;
  }

  /** Hann window: w[n] = 0.5 * (1 − cos(2π n / (N−1))). */
  function hannWindow(n) {
    var w = new Float64Array(n);
    if (n < 2) {
      if (n === 1) w[0] = 1;
      return w;
    }
    var den = n - 1;
    for (var i = 0; i < n; i++) w[i] = 0.5 * (1 - Math.cos(TWO_PI * i / den));
    return w;
  }

  /**
   * In-place radix-2 Cooley–Tukey FFT.
   * re/im are length `n` (power of two). Afterward they hold X[k].
   * Definition: X[k] = Σ x[n] exp(−j 2π k n / N).
   */
  function fftRadix2(re, im, n) {
    var i, j, k, m, step, half, wr, wi, tr, ti, ur, ui, theta;
    j = 0;
    for (i = 0; i < n; i++) {
      if (i < j) {
        tr = re[i]; re[i] = re[j]; re[j] = tr;
        ti = im[i]; im[i] = im[j]; im[j] = ti;
      }
      m = n >> 1;
      while (m >= 1 && j >= m) {
        j -= m;
        m >>= 1;
      }
      j += m;
    }
    for (step = 2; step <= n; step <<= 1) {
      half = step >> 1;
      theta = -TWO_PI / step;
      for (k = 0; k < n; k += step) {
        wr = 1;
        wi = 0;
        for (j = 0; j < half; j++) {
          var kr = k + j;
          var ki = kr + half;
          tr = wr * re[ki] - wi * im[ki];
          ti = wr * im[ki] + wi * re[ki];
          re[ki] = re[kr] - tr;
          im[ki] = im[kr] - ti;
          re[kr] += tr;
          im[kr] += ti;
          ur = wr * Math.cos(theta) - wi * Math.sin(theta);
          ui = wr * Math.sin(theta) + wi * Math.cos(theta);
          wr = ur;
          wi = ui;
        }
      }
    }
  }

  /**
   * Windowed real FFT → one-sided magnitude spectrum.
   *
   * @param {ArrayLike<number>} samples  time-domain (audio, or brightness vs time)
   * @param {number} sampleRate          Hz, or frames/s for a camera series
   * @param {{fftSize?: number, window?: string}} [opts]
   * @returns {{
   *   fftSize: number,
   *   binHz: number,
   *   window: string,
   *   magnitudes: Float64Array,  // length fftSize/2 + 1, linear magnitude
   *   peakBin: number,
   *   peakHz: number,
   *   peakMag: number
   * }}
   */
  function analyzeSpectrum(samples, sampleRate, opts) {
    opts = opts || {};
    var requested = opts.fftSize || DEFAULT_FFT_SIZE;
    var n = nextPow2(Math.max(2, requested));
    var windowName = opts.window || 'hann';
    var win = windowName === 'hann' ? hannWindow(n) : null;

    var re = new Float64Array(n);
    var im = new Float64Array(n);
    var copy = Math.min(samples.length, n);
    var i;
    for (i = 0; i < copy; i++) re[i] = samples[i];
    if (win) {
      for (i = 0; i < n; i++) re[i] *= win[i];
    }

    fftRadix2(re, im, n);

    var bins = (n >> 1) + 1;
    var mag = new Float64Array(bins);
    var peakBin = 0;
    var peakMag = 0;
    for (i = 0; i < bins; i++) {
      var m = Math.hypot(re[i], im[i]);
      mag[i] = m;
      /* Skip DC when hunting a tone / flicker peak. */
      if (i > 0 && m > peakMag) {
        peakMag = m;
        peakBin = i;
      }
    }

    var binHz = sampleRate / n;
    return {
      fftSize: n,
      binHz: binHz,
      window: windowName,
      magnitudes: mag,
      peakBin: peakBin,
      peakHz: peakBin * binHz,
      peakMag: peakMag
    };
  }

  /**
   * Fundamental via autocorrelation (more robust than raw FFT-peak for a
   * single tone / hum). FFT is still the right tool for a spectrum display
   * and for flicker; this is the pitch path.
   *
   * Finds the first significant ACF peak in [minHz, maxHz], with parabolic
   * interpolation around the lag.
   */
  function autocorrelationPitch(samples, sampleRate, opts) {
    opts = opts || {};
    var minHz = opts.minHz > 0 ? opts.minHz : 40;
    var maxHz = opts.maxHz > 0 ? opts.maxHz : 500;
    var threshold = opts.threshold != null ? opts.threshold : 0.25;
    var n = samples.length;
    if (n < 32 || !sampleRate) {
      return { hz: 0, confidence: 0, lag: 0 };
    }

    var mean = 0;
    var i;
    for (i = 0; i < n; i++) mean += samples[i];
    mean /= n;

    var x = new Float64Array(n);
    var r0 = 0;
    for (i = 0; i < n; i++) {
      x[i] = samples[i] - mean;
      r0 += x[i] * x[i];
    }
    if (r0 < 1e-18) return { hz: 0, confidence: 0, lag: 0 };

    var minLag = Math.max(2, Math.floor(sampleRate / maxHz));
    var maxLag = Math.min(n - 3, Math.floor(sampleRate / minHz));
    if (maxLag <= minLag) return { hz: 0, confidence: 0, lag: 0 };

    var r = new Float64Array(maxLag + 2);
    var lag;
    for (lag = minLag; lag <= maxLag; lag++) {
      var sum = 0;
      var count = n - lag;
      for (i = 0; i < count; i++) sum += x[i] * x[i + lag];
      r[lag] = sum / r0;
    }

    var peakLag = 0;
    var peakR = -Infinity;
    for (lag = minLag + 1; lag < maxLag; lag++) {
      if (r[lag] > r[lag - 1] && r[lag] >= r[lag + 1] && r[lag] > threshold) {
        peakLag = lag;
        peakR = r[lag];
        break;
      }
    }
    if (!peakLag) {
      for (lag = minLag; lag <= maxLag; lag++) {
        if (r[lag] > peakR) {
          peakR = r[lag];
          peakLag = lag;
        }
      }
    }
    if (!peakLag || peakR < 0.05) return { hz: 0, confidence: Math.max(0, peakR), lag: 0 };

    var r1 = r[peakLag - 1] || 0;
    var r2 = r[peakLag];
    var r3 = r[peakLag + 1] || 0;
    var denom = (r2 - r1) - (r3 - r2);
    var interp = peakLag;
    if (Math.abs(denom) > 1e-12) interp = peakLag + 0.5 * (r1 - r3) / denom;

    return {
      hz: sampleRate / interp,
      confidence: peakR,
      lag: interp
    };
  }

  function rms(samples) {
    if (!samples || !samples.length) return 0;
    var s = 0;
    for (var i = 0; i < samples.length; i++) s += samples[i] * samples[i];
    return Math.sqrt(s / samples.length);
  }

  /** 20 log10(rms). Full-scale float is 1.0. −Infinity for digital silence. */
  function dbfs(samples) {
    var r = rms(samples);
    if (r <= 0) return -Infinity;
    return 20 * Math.log10(r);
  }

  /**
   * IEC 61672-1 A-weighting in dB, 0 dB at 1 kHz by definition.
   * Approximation of the analog filter — not a certified SLM filter.
   */
  function aWeightDb(freqHz) {
    if (!(freqHz > 0) || !isFinite(freqHz)) return -1e6;
    var f2 = freqHz * freqHz;
    var c1 = 12194.217;
    var c2 = 20.598997;
    var c3 = 107.65265;
    var c4 = 737.86223;
    var num = (c1 * c1) * f2 * f2;
    var den = (f2 + c2 * c2) *
      Math.sqrt((f2 + c3 * c3) * (f2 + c4 * c4)) *
      (f2 + c1 * c1);
    var ra = num / den;
    var ra1k = (c1 * c1) * 1e12 /
      ((1e6 + c2 * c2) * Math.sqrt((1e6 + c3 * c3) * (1e6 + c4 * c4)) * (1e6 + c1 * c1));
    if (ra <= 0 || ra1k <= 0) return -1e6;
    return 20 * Math.log10(ra / ra1k);
  }

  /**
   * A-weighting correction from a windowed spectrum: 10 log10(P_A / P).
   * Add this to unweighted dBFS for an approximate A-weighted reading.
   * A 1 kHz tone → ~0 dB; a 100 Hz tone → ~−19 dB.
   */
  function aWeightCorrectionDb(samples, sampleRate, opts) {
    var spec = analyzeSpectrum(samples, sampleRate, opts);
    var p = 0;
    var pA = 0;
    var mag = spec.magnitudes;
    for (var k = 1; k < mag.length; k++) {
      var m2 = mag[k] * mag[k];
      var f = k * spec.binHz;
      var w = Math.pow(10, aWeightDb(f) / 10);
      p += m2;
      pA += m2 * w;
    }
    if (p <= 0) return 0;
    return 10 * Math.log10(pA / p);
  }

  /**
   * Center-weighted mean luminance of an RGBA ImageData-like buffer.
   * Samples a circular region (~28% of the short side) with a cosine falloff
   * so the reading is not a full-frame average (windows, fixtures at the
   * edge would dominate). Rec. 601 luma.
   */
  function centerWeightedLuminance(data, width, height) {
    if (!data || !width || !height) return 0;
    var cx = (width - 1) / 2;
    var cy = (height - 1) / 2;
    var radius = Math.max(2, 0.28 * Math.min(width, height));
    var r2 = radius * radius;
    var sum = 0;
    var wsum = 0;
    var x, y, dx, dy, d2, w, i, y601;
    for (y = 0; y < height; y++) {
      dy = y - cy;
      for (x = 0; x < width; x++) {
        dx = x - cx;
        d2 = dx * dx + dy * dy;
        if (d2 > r2) continue;
        w = 0.5 * (1 + Math.cos(Math.PI * Math.sqrt(d2) / radius));
        i = (y * width + x) * 4;
        y601 = 0.299 * data[i] + 0.587 * data[i + 1] + 0.114 * data[i + 2];
        sum += y601 * w;
        wsum += w;
      }
    }
    if (wsum <= 0) return 0;
    /* Relative unit: 0–100, not lux. */
    return (sum / wsum) / 2.55;
  }

  /**
   * One-point lux calibration. Without a scale factor the reading stays in
   * a clearly-labeled relative unit — never implied to be lux.
   */
  function applyLuxCalibration(relative, scale) {
    var rel = Number(relative);
    if (!isFinite(rel)) rel = 0;
    var s = Number(scale);
    if (s > 0 && isFinite(s)) {
      return { value: rel * s, unit: 'lx', calibrated: true, relative: rel };
    }
    return { value: rel, unit: 'rel', calibrated: false, relative: rel };
  }

  /**
   * One-point SPL offset. Without it, show a relative dBFS (or rel dB),
   * never unearned dB(A).
   */
  function applySplCalibration(dbfsValue, offsetDb, aWeighted) {
    var v = Number(dbfsValue);
    if (!isFinite(v)) v = -Infinity;
    var hasOffset = offsetDb !== null && offsetDb !== undefined && offsetDb !== '' && isFinite(Number(offsetDb));
    var off = hasOffset ? Number(offsetDb) : 0;
    var display = v + off;
    var unit;
    if (hasOffset && aWeighted) unit = 'dB(A) approx';
    else if (hasOffset) unit = 'dB (uncert. phone)';
    else if (aWeighted) unit = 'rel dB(A) approx';
    else unit = 'dBFS';
    return {
      value: display,
      unit: unit,
      calibrated: hasOffset,
      aWeighted: !!aWeighted,
      dbfs: v
    };
  }

  function binHz(sampleRate, fftSize) {
    return sampleRate / nextPow2(Math.max(2, fftSize || DEFAULT_FFT_SIZE));
  }

  var api = {
    DEFAULT_FFT_SIZE: DEFAULT_FFT_SIZE,
    WINDOW: 'hann',
    nextPow2: nextPow2,
    hannWindow: hannWindow,
    fftRadix2: fftRadix2,
    analyzeSpectrum: analyzeSpectrum,
    autocorrelationPitch: autocorrelationPitch,
    rms: rms,
    dbfs: dbfs,
    aWeightDb: aWeightDb,
    aWeightCorrectionDb: aWeightCorrectionDb,
    centerWeightedLuminance: centerWeightedLuminance,
    applyLuxCalibration: applyLuxCalibration,
    applySplCalibration: applySplCalibration,
    binHz: binHz
  };

  global.BeckifySensorFft = api;
  global.__sensorFftTestApi = api;
})(typeof window !== 'undefined' ? window : globalThis);
