!=================================================================================================================================
! Copyright (c) 2016  Prof. Claus-Dieter Munz 
! This file is part of FLEXI, a high-order accurate framework for numerically solving PDEs with discontinuous Galerkin methods.
! For more information see https://www.flexi-project.org and https://nrg.iag.uni-stuttgart.de/
!
! FLEXI is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License 
! as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
!
! FLEXI is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
! of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License v3.0 for more details.
!
! You should have received a copy of the GNU General Public License along with FLEXI. If not, see <http://www.gnu.org/licenses/>.
!=================================================================================================================================
#include "flexi.h"
#include "eos.h"

!==================================================================================================================================
!> Contains the routine EvalFlux3D which computes the complete NSE flux f,g,h for all DOFs in one Element: used in volume integral
!> Contains the routine EvalFlux1D_Adv which computes the Euler flux f for all DOFs of one Element side: used in Riemann_Adv
!==================================================================================================================================
MODULE MOD_Flux
! MODULES
IMPLICIT NONE
PRIVATE
!----------------------------------------------------------------------------------------------------------------------------------
! GLOBAL VARIABLES
!----------------------------------------------------------------------------------------------------------------------------------
! Private Part ---------------------------------------------------------------------------------------------------------------------
! Public Part ----------------------------------------------------------------------------------------------------------------------
INTERFACE EvalFlux3D
  MODULE PROCEDURE EvalFlux3D
END INTERFACE

INTERFACE EvalEulerFlux1D
  MODULE PROCEDURE EvalEulerFlux1D
END INTERFACE
INTERFACE EvalEulerFlux1D_fast
  MODULE PROCEDURE EvalEulerFlux1D_fast
END INTERFACE

#ifdef PARABOLIC
INTERFACE EvalDiffFlux3D
  MODULE PROCEDURE EvalDiffFlux3D
END INTERFACE

INTERFACE EvalDiffFlux2D
  MODULE PROCEDURE EvalDiffFlux2D
END INTERFACE

!INTERFACE EvalDiffFlux1D !only for testing
!  MODULE PROCEDURE EvalDiffFlux1D
!END INTERFACE
#endif /*PARABOLIC*/

PUBLIC::EvalFlux3D,EvalEulerFlux1D,EvalEulerFlux1D_fast
#ifdef PARABOLIC
PUBLIC::EvalDiffFlux3D,EvalDiffFlux2D!,EvalDiffFlux1D
#endif /*PARABOLIC*/
!==================================================================================================================================

CONTAINS

!==================================================================================================================================
!> Compute Navier-Stokes fluxes using the conservative variables and derivatives for every volume Gauss point.
!==================================================================================================================================
SUBROUTINE EvalFlux3D(NLoc,U,f,g,h)
! MODULES
USE MOD_PreProc
USE MOD_Equation_Vars,ONLY:kappaM1
IMPLICIT NONE
!----------------------------------------------------------------------------------------------------------------------------------
! INPUT / OUTPUT VARIABLES
INTEGER,INTENT(IN) :: NLoc
REAL,DIMENSION(5,0:NLoc,0:NLoc,0:NLoc),INTENT(IN)  :: U
REAL,DIMENSION(5,0:NLoc,0:NLoc,0:NLoc),INTENT(OUT) :: f,g,h    ! Cartesian fluxes (iVar,i,j,k)
!----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
REAL                :: srho                                    ! reciprocal values for density and the value of specific energy
REAL                :: v1,v2,v3,p                              ! auxiliary variables
REAL                :: Ep                                      ! E + p
INTEGER             :: i,j,k
!==================================================================================================================================
DO k=0,NLoc;  DO j=0,NLoc; DO i=0,NLoc
  ! auxiliary variables
  srho = 1. / U(1,i,j,k) ! 1/rho
  v1   = U(2,i,j,k)*srho
  v2   = U(3,i,j,k)*srho
  v3   = U(4,i,j,k)*srho
  p    = kappaM1*(U(5,i,j,k)-0.5*U(1,i,j,k)*(v1*v1+v2*v2+v3*v3))
  Ep   = (U(5,i,j,k) + p)
  ! Euler part
  ! Euler fluxes x-direction
  f(1,i,j,k)=U(2,i,j,k)      ! rho*u
  f(2,i,j,k)=U(2,i,j,k)*v1+p ! rho*u²+p
  f(3,i,j,k)=U(2,i,j,k)*v2   ! rho*u*v
  f(4,i,j,k)=U(2,i,j,k)*v3   ! rho*u*w
  f(5,i,j,k)=Ep*v1            ! (rho*e+p)*u
  ! Euler fluxes y-direction
  g(1,i,j,k)=U(3,i,j,k)      ! rho*v
  g(2,i,j,k)=f(3,i,j,k)      ! rho*u*v
  g(3,i,j,k)=U(3,i,j,k)*v2+p ! rho*v²+p
  g(4,i,j,k)=U(3,i,j,k)*v3   ! rho*v*w
  g(5,i,j,k)=Ep*v2            ! (rho*e+p)*v
  ! Euler fluxes z-direction
  h(1,i,j,k)=U(4,i,j,k)      ! rho*v
  h(2,i,j,k)=f(4,i,j,k)      ! rho*u*w
  h(3,i,j,k)=g(4,i,j,k)      ! rho*v*w
  h(4,i,j,k)=U(4,i,j,k)*v3+p ! rho*v²+p
  h(5,i,j,k)=Ep*v3            ! (rho*e+p)*w
END DO; END DO; END DO ! i,j,k
END SUBROUTINE EvalFlux3D


#ifdef PARABOLIC
!==================================================================================================================================
!> Compute Navier-Stokes diffusive fluxes using the conservative variables and derivatives for every volume Gauss point.
!==================================================================================================================================
SUBROUTINE EvalDiffFlux3D(U,gradUx,gradUy,gradUz,f,g,h,iElem)
! MODULES
USE MOD_PreProc
USE MOD_Equation_Vars,ONLY: cp,Pr
USE MOD_EOS,          ONLY: GETVISC
#ifdef EDDYVISCOSITY
USE MOD_Equation_vars ,ONLY:eddyViscosity  !Pointer to eddy viscosity Model
USE MOD_EddyVisc_vars ,ONLY:muSGS
USE MOD_Equation_vars ,ONLY:eddyViscType
USE MOD_EddyVisc_Vars ,ONLY:PrSGS
#endif
IMPLICIT NONE
!----------------------------------------------------------------------------------------------------------------------------------
! INPUT / OUTPUT VARIABLES
REAL,DIMENSION(PP_nVar,0:PP_N,0:PP_N,0:PP_N),INTENT(IN)  :: U,gradUx,gradUy,gradUz
REAL,DIMENSION(PP_nVar,0:PP_N,0:PP_N,0:PP_N),INTENT(OUT) :: f,g,h             ! Cartesian fluxes (iVar,i,j,k)
INTEGER, INTENT(IN)                                      :: iELem
!----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
REAL                :: srho,muS,s43,s23
REAL                :: v1,v2,v3
REAL                :: tau_xx,tau_yy,tau_zz,tau_xy,tau_xz,tau_yz
REAL                :: gradT1,gradT2,gradT3,lambda
INTEGER             :: i,j,k
!==================================================================================================================================
s43=4./3.
s23=2./3.
DO k=0,PP_N;  DO j=0,PP_N; DO i=0,PP_N
  srho = 1. / U(1,i,j,k) ! 1/rho
  v1   = U(2,i,j,k)*srho
  v2   = U(3,i,j,k)*srho
  v3   = U(4,i,j,k)*srho
  ! Viscous part
  ! ideal gas law
  muS=GETVISC(U(:,i,j,k))
  lambda=muS*cp/Pr
!Add turbulent sub grid scale viscosity to mu
#ifdef EDDYVISCOSITY
  CALL eddyViscosity(gradUx(2,i,j,k),gradUy(3,i,j,k),gradUz(4,i,j,k)&
                    ,gradUy(2,i,j,k),gradUz(2,i,j,k),gradUx(3,i,j,k)&
                    ,gradUz(3,i,j,k),gradUx(4,i,j,k),gradUy(4,i,j,k)&
                    ,U(1,i,j,k),iElem,i,j,k,muSGS(i,j,k,iElem))
  muS = muS + max(muSGS(i,j,k,iElem),0.)
  lambda = lambda + muSGS(i,j,k,iElem)*cp/PrSGS
#endif

  ! In previous versions gradients of conservative variables had been used, see Git commit b984f2895121e236ce24c149ad15615180995b00
  ! gradients of primitive variables are directly available gradU = (/ drho, dv1, dv2, dv3, dT /)
  ! viscous fluxes in x-direction
  tau_xx=muS*( s43*gradUx(2,i,j,k)-s23*gradUy(3,i,j,k)-s23*gradUz(4,i,j,k)) ! 4/3*mu*u_x-2/3*mu*v_y -2/3*mu*w*z
  tau_yy=muS*(-s23*gradUx(2,i,j,k)+s43*gradUy(3,i,j,k)-s23*gradUz(4,i,j,k)) !-2/3*mu*u_x+4/3*mu*v_y -2/3*mu*w*z
  tau_zz=muS*(-s23*gradUx(2,i,j,k)-s23*gradUy(3,i,j,k)+s43*gradUz(4,i,j,k)) !-2/3*mu*u_x-2/3*mu*v_y +4/3*mu*w*z
  tau_xy=muS*(gradUy(2,i,j,k)+gradUx(3,i,j,k))                               !mu*(u_y+v_x)
  tau_xz=muS*(gradUz(2,i,j,k)+gradUx(4,i,j,k))                               !mu*(u_z+w_x)
  tau_yz=muS*(gradUz(3,i,j,k)+gradUy(4,i,j,k))                               !mu*(y_z+w_y)

  gradT1=gradUx(5,i,j,k)
  gradT2=gradUy(5,i,j,k)
  gradT3=gradUz(5,i,j,k)

  f(1,i,j,k)=0.
  f(2,i,j,k)=-tau_xx                                       ! F_euler-4/3*mu*u_x+2/3*mu*(v_y+w_z)
  f(3,i,j,k)=-tau_xy                                       ! F_euler-mu*(u_y+v_x)
  f(4,i,j,k)=-tau_xz                                       ! F_euler-mu*(u_z+w_x)
  f(5,i,j,k)=-tau_xx*v1-tau_xy*v2-tau_xz*v3-lambda*gradT1  ! F_euler-(tau_xx*u+tau_xy*v+tau_xz*w-q_x) q_x=-lambda*T_x
  ! viscous fluxes in y-direction
  g(1,i,j,k)=0.
  g(2,i,j,k)=-tau_xy                                       ! F_euler-mu*(u_y+v_x)
  g(3,i,j,k)=-tau_yy                                       ! F_euler-4/3*mu*v_y+2/3*mu*(u_x+w_z)
  g(4,i,j,k)=-tau_yz                                       ! F_euler-mu*(y_z+w_y)
  g(5,i,j,k)=-tau_xy*v1-tau_yy*v2-tau_yz*v3-lambda*gradT2  ! F_euler-(tau_yx*u+tau_yy*v+tau_yz*w-q_y) q_y=-lambda*T_y
  ! viscous fluxes in z-direction
  h(1,i,j,k)=0.
  h(2,i,j,k)=-tau_xz                                       ! F_euler-mu*(u_z+w_x)
  h(3,i,j,k)=-tau_yz                                       ! F_euler-mu*(y_z+w_y)
  h(4,i,j,k)=-tau_zz                                       ! F_euler-4/3*mu*w_z+2/3*mu*(u_x+v_y)
  h(5,i,j,k)=-tau_xz*v1-tau_yz*v2-tau_zz*v3-lambda*gradT3  ! F_euler-(tau_zx*u+tau_zy*v+tau_zz*w-q_z) q_z=-lambda*T_z

END DO; END DO; END DO ! i,j,k

i = iElem ! dummy access to ielem, to avoid compiler warnings, when compiled without EDDYVISCOSITY
END SUBROUTINE EvalDiffFlux3D
#endif /*PARABOLIC*/


!==================================================================================================================================
!> Computes 1D Euler flux using the conservative variables.
!==================================================================================================================================
PURE SUBROUTINE EvalEulerFlux1D(U,F)
! MODULES
USE MOD_Equation_Vars,ONLY:KappaM1
IMPLICIT NONE
!----------------------------------------------------------------------------------------------------------------------------------
! INPUT / OUTPUT VARIABLES
REAL,INTENT(IN)     :: U(PP_nVar) !< vector of conservative variables
REAL,INTENT(OUT)    :: F(PP_nVar) !< Cartesian flux in "x" direction
!----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
REAL                :: v(3),p      ! auxiliary variables
!==================================================================================================================================
! auxiliary variables
v = U(MOMV)/U(DENS)
p = PRESSURE_H(U,v)
! Euler fluxes x-direction
F(1)= U(MOM1)          ! rho*u
F(2)= U(MOM1)*v(1)+p   ! rho*u²+p
F(3)= U(MOM1)*v(2)     ! rho*u*v
F(4)= U(MOM1)*v(3)     ! rho*u*w
F(5)=(U(ENER)+p)*v(1)  ! (rho*e+p)*u
END SUBROUTINE EvalEulerFlux1D
!==================================================================================================================================
!> Computes 1D Euler flux using the conservative and primitive variables (for better performance)
!==================================================================================================================================
PURE SUBROUTINE EvalEulerFlux1D_fast(U,F)
! MODULES
IMPLICIT NONE
!----------------------------------------------------------------------------------------------------------------------------------
! INPUT / OUTPUT VARIABLES
REAL,INTENT(IN)     :: U(PP_2Var) !< vector of conservative and primitive variables
REAL,INTENT(OUT)    :: F(PP_nVar) !< Cartesian flux in "x" direction
!----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
!==================================================================================================================================
! Euler fluxes x-direction
F(1)= U(MOM1)                 ! rho*u
F(2)= U(MOM1)*U(VEL1)+U(PRES) ! rho*u²+p
F(3)= U(MOM1)*U(VEL2)         ! rho*u*v
F(4)= U(MOM1)*U(VEL3)         ! rho*u*w
F(5)=(U(ENER)+U(PRES))*U(VEL1)! (rho*e+p)*u
END SUBROUTINE EvalEulerFlux1D_fast


#ifdef PARABOLIC
!==================================================================================================================================
!> Compute Navier-Stokes diffusive fluxes using the conservative variables and derivatives for every volume Gauss point.
!==================================================================================================================================
SUBROUTINE EvalDiffFlux2D(Nloc,f,g,h,U_Face,gradUx_Face,gradUy_Face,gradUz_Face&
#ifdef EDDYVISCOSITY
                    ,DeltaS,SGS_Ind,Face_xGP&
#endif
)
! MODULES
USE MOD_PreProc
USE MOD_Equation_Vars,ONLY: cp,Pr
USE MOD_EOS,          ONLY: GETVISC
#ifdef EDDYVISCOSITY
USE MOD_Equation_vars ,ONLY:eddyViscosity_surf  !Pointer to eddy viscosity Model
USE MOD_Equation_vars ,ONLY:eddyViscType
USE MOD_EddyVisc_Vars ,ONLY:PrSGS
#endif
IMPLICIT NONE
!----------------------------------------------------------------------------------------------------------------------------------
! INPUT / OUTPUT VARIABLES
INTEGER,INTENT(IN)  :: Nloc
REAL,INTENT(IN)     :: U_Face(5,0:Nloc,0:Nloc)                    ! U_Face(iVar,i,j,k)
REAL,INTENT(IN)     :: gradUx_Face(5,0:Nloc,0:Nloc)               ! gradUx_Face(iVar,j,k)
REAL,INTENT(IN)     :: gradUy_Face(5,0:Nloc,0:Nloc)               ! gradUy_Face(iVar,i,k)
REAL,INTENT(IN)     :: gradUz_Face(5,0:Nloc,0:Nloc)               ! gradUz_Face(iVar,i,j)
REAL,DIMENSION(5,0:Nloc,0:Nloc),INTENT(OUT) :: f,g,h              ! Cartesian fluxes (iVar,i,j)
#ifdef EDDYVISCOSITY 
REAL,INTENT(IN)     :: SGS_Ind(0:Nloc,0:Nloc), DeltaS             ! Inicator and filter width for eddy viscosity
REAL,INTENT(IN)     :: Face_xGP(3,0:NLoc,0:NLoc) 
#endif 
!----------------------------------------------------------------------------------------------------------------------------------
! LOCAL VARIABLES
REAL                :: srho,muS,s43,s23
REAL                :: v1,v2,v3
REAL                :: tau_xx,tau_yy,tau_zz,tau_xy,tau_xz,tau_yz
REAL                :: gradT1,gradT2,gradT3,lambda
INTEGER             :: i,j
#ifdef EDDYVISCOSITY 
REAL                :: muSGS 
#endif 
!==================================================================================================================================
s43=4./3.
s23=2./3.
DO j=0,Nloc ; DO i=0,Nloc
  ! auxiliary variables
  srho = 1. / U_Face(1,i,j) ! 1/rho
  v1   = U_Face(2,i,j)*srho
  v2   = U_Face(3,i,j)*srho
  v3   = U_Face(4,i,j)*srho
  ! ideal gas law
  muS=GETVISC(U_Face(:,i,j))

  ! In previous versions gradients of conservative variables had been used, see Git commit b984f2895121e236ce24c149ad15615180995b00
  ! gradients of primitive variables are directly available gradU = (/ drho, dv1, dv2, dv3, dT /)
  lambda=muS*cp/Pr
#ifdef EDDYVISCOSITY
  CALL eddyViscosity_surf(gradUx_Face(2,i,j),gradUy_Face(3,i,j),gradUz_Face(4,i,j)&
                         ,gradUy_Face(2,i,j),gradUz_Face(2,i,j),gradUx_Face(3,i,j)&
                         ,gradUz_Face(3,i,j),gradUx_Face(4,i,j),gradUy_Face(4,i,j)&
                         ,U_Face(1,i,j),DeltaS,SGS_Ind,muSGS,Face_xGP(2,i,j))
  muS = muS + max(muSGS,0.)
  lambda = lambda + muSGS*cp/PrSGS
#endif

  ! viscous fluxes in x-direction
  tau_xx=muS*( s43*gradUx_Face(2,i,j)-s23*gradUy_Face(3,i,j)-s23*gradUz_Face(4,i,j)) ! 4/3*mu*u_x-2/3*mu*v_y -2/3*mu*w*z
  tau_yy=muS*(-s23*gradUx_Face(2,i,j)+s43*gradUy_Face(3,i,j)-s23*gradUz_Face(4,i,j)) !-2/3*mu*u_x+4/3*mu*v_y -2/3*mu*w*z
  tau_zz=muS*(-s23*gradUx_Face(2,i,j)-s23*gradUy_Face(3,i,j)+s43*gradUz_Face(4,i,j)) !-2/3*mu*u_x-2/3*mu*v_y +4/3*mu*w*z
  tau_xy=muS*(gradUy_Face(2,i,j)+gradUx_Face(3,i,j))                                   !mu*(u_y+v_x)
  tau_xz=muS*(gradUz_Face(2,i,j)+gradUx_Face(4,i,j))                                   !mu*(u_z+w_x)
  tau_yz=muS*(gradUz_Face(3,i,j)+gradUy_Face(4,i,j))                                   !mu*(y_z+w_y)
  gradT1=gradUx_Face(5,i,j)
  gradT2=gradUy_Face(5,i,j)
  gradT3=gradUz_Face(5,i,j)
  f(1,i,j)=0.
  f(2,i,j)=-tau_xx                                       ! F_euler-4/3*mu*u_x+2/3*mu*(v_y+w_z)
  f(3,i,j)=-tau_xy                                       ! F_euler-mu*(u_y+v_x)
  f(4,i,j)=-tau_xz                                       ! F_euler-mu*(u_z+w_x)
  f(5,i,j)=-tau_xx*v1-tau_xy*v2-tau_xz*v3-lambda*gradT1  ! F_euler-(tau_xx*u+tau_xy*v+tau_xz*w-q_x) q_x=-lambda*T_x
  ! viscous fluxes in y-direction
  g(1,i,j)=0.
  g(2,i,j)=-tau_xy                                       ! F_euler-mu*(u_y+v_x)
  g(3,i,j)=-tau_yy                                       ! F_euler-4/3*mu*v_y+2/3*mu*(u_x+w_z)
  g(4,i,j)=-tau_yz                                       ! F_euler-mu*(y_z+w_y)
  g(5,i,j)=-tau_xy*v1-tau_yy*v2-tau_yz*v3-lambda*gradT2  ! F_euler-(tau_yx*u+tau_yy*v+tau_yz*w-q_y) q_y=-lambda*T_y
  ! viscous fluxes in z-direction
  h(1,i,j)=0.
  h(2,i,j)=-tau_xz                                       ! F_euler-mu*(u_z+w_x)
  h(3,i,j)=-tau_yz                                       ! F_euler-mu*(y_z+w_y)
  h(4,i,j)=-tau_zz                                       ! F_euler-4/3*mu*w_z+2/3*mu*(u_x+v_y)
  h(5,i,j)=-tau_xz*v1-tau_yz*v2-tau_zz*v3-lambda*gradT3  ! F_euler-(tau_zx*u+tau_zy*v+tau_zz*w-q_z) q_z=-lambda*T_z

END DO ; END DO !i,j
END SUBROUTINE EvalDiffFlux2D
#endif /*PARABOLIC*/

END MODULE MOD_Flux
