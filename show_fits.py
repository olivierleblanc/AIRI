import numpy as np
import matplotlib.pyplot as plt
import astropy.io.fits as fits

directory = 'C:/Users/leblanco.OASIS/Documents/IngeCivilPHD/codes/radio_interferometry/AIRI/results/-AIRI_heuScale_1_maxItr_1000/'

# GT
gt = fits.open(directory+'GT.fits')[0].data

plt.figure()
plt.imshow(np.real(gt), cmap='jet')
plt.colorbar()

# dirty image
dirty = fits.open(directory+'dirty.fits')[0].data

plt.figure()
plt.imshow(np.real(dirty), cmap='jet')
plt.colorbar()
plt.title('Dirty image')

# reconstruction
rec = fits.open(directory+'tmpModel_itr_400.fits')[0].data

plt.figure()
plt.imshow(np.real(rec), cmap='jet')
plt.colorbar()
plt.title('Reconstruction')

# residual
residual = fits.open(directory+'tmpResidual_itr_400.fits')[0].data

plt.figure()
plt.imshow(np.real(residual), cmap='jet')
plt.colorbar()
plt.title('Residual')

# compute the SNR
snr = 20*np.log10(np.linalg.norm(gt.flatten())/np.linalg.norm(gt.flatten()-rec.flatten()))
print('SNR: {:.2f} dB'.format(snr))

plt.show()